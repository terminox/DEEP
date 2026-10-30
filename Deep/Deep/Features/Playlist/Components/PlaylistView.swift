import SwiftUI

/// The You tab's home: the sounds this listener saved, with the system settings
/// behind the gear in the header's trailing slot.
///
/// No hero. The other four tabs open on a full-bleed video because each has
/// something to set a mood for; a playlist is a list you came to use, and a
/// 320pt sky would push the first sound below the fold. The title stays pinned
/// instead, in the same place the hero-led tabs park theirs.
///
/// This is the leaf screen, so it owns its screen-level styling —
/// `AtmosphereBackground` sits behind the scroll here rather than in the
/// coordinator, where the `NavigationStack` would hide it.
struct PlaylistView: View {
  /// Extra bottom space so content clears the docked mini player.
  var bottomInset: CGFloat

  @Environment(\.playlistStore) private var store
  @Environment(\.soundPlayer) private var player
  @Environment(\.premiumAccess) private var premiumAccess
  @Environment(\.openSettings) private var openSettings
  @Environment(\.openDeepSound) private var openDeepSound
  @Environment(\.openPaywall) private var openPaywall

  private var entries: [PlaylistEntry] { store.entries }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: .rhythm) {
        content
          .animation(.bloom, value: entries)
          .animation(.bloom, value: store.hasLoaded)

        Color.clear.frame(height: bottomInset)
      }
      .padding(.top, .rhythm)
    }
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.always)
    // The header is a bar, so a card reaching it gets the system's edge effect.
    // Named rather than left to `.automatic`: `.hard` draws the separator line
    // this design language rules out.
    .scrollEdgeEffectStyle(.soft, for: .top)
    .background { AtmosphereBackground() }
    // Before the header inset, so the pull cue measures the true safe-area top
    // and parks where it does on every other tab.
    .heroRefreshable { await store.refresh() }
    .pinnedHomeHeader(title: "Playlist", subtitle: "Sounds you've saved") {
      HeaderIconButton(systemName: "gearshape", accessibilityLabel: "Settings") {
        openSettings()
      }
    }
    .task { await store.refreshIfNeeded() }
    // Saved sounds carry the server's withheld-audio verdicts too, so a change
    // in the premium answer re-fetches them. Not a `.task(id:)`: its first run
    // would turn the once-per-visit `refreshIfNeeded` into a fetch on every
    // visit.
    .onChange(of: premiumAccess.contentEpoch) {
      Task { await store.refresh() }
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var content: some View {
    if !store.hasLoaded {
      PlaylistSkeleton()
        .transition(.opacity)
    } else if store.loadFailed {
      failure
    } else if entries.isEmpty {
      invitation
    } else {
      saved
    }
  }

  private var saved: some View {
    VStack(spacing: .rhythm) {
      HStack(spacing: 12) {
        SoundActionButton(title: "Play", systemName: "play.fill") {
          playAll(shuffled: false)
        }
        SoundActionButton(title: "Shuffle", systemName: "shuffle") {
          playAll(shuffled: true)
        }
      }

      LazyVStack(spacing: 14) {
        ForEach(Array(entries.enumerated()), id: \.element.id) { pair in
          let (offset, entry) = pair
          PlaylistTrackRow(
            entry: entry,
            isCurrent: isCurrent(entry),
            isLocked: isLocked(entry),
            play: { attemptPlay(at: offset) },
            remove: { store.remove(entry) }
          )
        }
      }
    }
    .padding(.horizontal, .edge)
  }

  /// Genuine emptiness reads as an invitation, not a fault — and never as a
  /// dimmed button.
  ///
  /// No panel around the words. A full-width frosted pill carries the weight of
  /// *content* on the one screen whose whole message is that there is none, and
  /// parked under the header it reads as a banner. The lines sit bare on the
  /// atmosphere with room above them instead, so the only surface left on screen
  /// is the way out — the same frosted chip the failure branch below already
  /// wears, hugging its text rather than stretching like `SoundActionButton`.
  private var invitation: some View {
    VStack(spacing: 18) {
      VStack(spacing: 6) {
        Text("Nothing saved yet")
          .font(DeepType.sectionTitle)
          .foregroundStyle(.deepPlum)
        Text("Save a sound while it's playing and it'll be waiting here.")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .multilineTextAlignment(.center)
          // Held short of the full width: run edge to edge and one grey line
          // reads as a banner rather than a note.
          .frame(maxWidth: 260)
      }

      Button(action: openDeepSound) {
        Text("Explore DEEP Sound")
          .font(DeepType.body.weight(.medium))
          .foregroundStyle(.deepPlum)
          .padding(.horizontal, 22)
          .padding(.vertical, 12)
          .frostedCard(cornerRadius: .chip)
      }
      .buttonStyle(.softPress)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, .edge)
    // Air, so this lands as a note in an empty room rather than a headline
    // pinned to the top. Stacks on the body's own `.rhythm`.
    .padding(.top, 72)
  }

  private var failure: some View {
    VStack(spacing: 14) {
      Text("We couldn't reach your playlist just now.")
        .font(DeepType.body)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
      Button {
        Task { await store.refresh() }
      } label: {
        Text("Try again")
          .font(DeepType.body.weight(.medium))
          .foregroundStyle(.deepPlum)
          .padding(.horizontal, 22)
          .padding(.vertical, 12)
          .frostedCard(cornerRadius: .chip)
      }
      .buttonStyle(.softPress)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, .edge)
    .padding(.vertical, 48)
  }

  // MARK: - Playback

  private func isCurrent(_ entry: PlaylistEntry) -> Bool {
    player.currentTrack?.id == entry.track.id
      && player.collection?.id == entry.collection.id
  }

  private func isLocked(_ entry: PlaylistEntry) -> Bool {
    PremiumGate.isLocked(entry.track, in: entry.collection, hasPremium: premiumAccess.hasPremium)
  }

  /// The saved sounds this listener can play, in order. Play, Shuffle and a
  /// tapped row all queue these, so a run never carries on into a locked one.
  private var playable: [SoundQueueEntry] {
    PremiumGate.playable(entries.map(\.queueEntry), hasPremium: premiumAccess.hasPremium)
  }

  /// Starts the whole playlist from one sound, so what follows is the rest of
  /// what this listener saved — each entry carrying its own collection, which
  /// is what lets the artwork and the origin line change track by track.
  /// A locked sound — or one whose audio the server withheld — opens the
  /// invitation instead, the same door a collection opens.
  private func attemptPlay(at index: Int) {
    guard entries.indices.contains(index) else { return }
    let entry = entries[index]
    if !PremiumGate.canStart(entry.track, in: entry.collection, hasPremium: premiumAccess.hasPremium) {
      openPaywall(.lockedSound)
    } else {
      let queue = playable
      // Matched on the track and its origin: a queue entry carries no
      // playlist id, and the same sound is saved at most once.
      let index = queue.firstIndex {
        $0.track.id == entry.track.id && $0.collection.id == entry.collection.id
      }
      player.play(queue, at: index ?? 0)
    }
  }

  /// Play sets off from the top in order; Shuffle deals the whole playlist in
  /// a random order.
  private func playAll(shuffled: Bool) {
    guard !entries.isEmpty else { return }
    let queue = playable
    if queue.isEmpty {
      openPaywall(.lockedSound)
    } else {
      player.play(queue, at: shuffled ? nil : 0, shuffled: shuffled)
    }
  }
}

#if DEBUG
#Preview("Playlist — saved sounds") {
  PlaylistView(bottomInset: .rhythm)
    .environment(\.playlistStore, .sample)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}

#Preview("Playlist — a premium sound, locked") {
  PlaylistView(bottomInset: .rhythm)
    .environment(\.playlistStore, .withPremium)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
    .environment(\.premiumAccess, .free)
}

#Preview("Playlist — nothing saved") {
  PlaylistView(bottomInset: .rhythm)
    .environment(\.playlistStore, .empty)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}

#Preview("Playlist — loading") {
  PlaylistView(bottomInset: .rhythm)
    .environment(\.playlistStore, .loading)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}

#Preview("Playlist — unreachable") {
  PlaylistView(bottomInset: .rhythm)
    .environment(\.playlistStore, .failed)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}
#endif
