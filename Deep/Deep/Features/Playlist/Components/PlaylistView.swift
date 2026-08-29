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
  @Environment(\.subscriptionStore) private var subscriptionStore
  @Environment(\.openSettings) private var openSettings
  @Environment(\.openDeepSound) private var openDeepSound

  @State private var showPremiumGate = false

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
    .alert("A premium sound", isPresented: $showPremiumGate) {
      Button("Maybe later", role: .cancel) {}
    } message: {
      Text("This one is part of DEEP Premium. It'll be here whenever you're ready.")
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
          attemptPlay(at: 0)
        }
        SoundActionButton(title: "Shuffle", systemName: "shuffle") {
          attemptPlay(at: Int.random(in: 0..<max(1, entries.count)))
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
        Text("Explore Deep Sound")
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
    (entry.collection.isPremium || entry.track.isPremium) && !subscriptionStore.isSubscribed
  }

  /// Starts the whole playlist from one sound, so what follows is the rest of
  /// what this listener saved — each entry carrying its own collection, which
  /// is what lets the artwork and the origin line change track by track.
  /// Locked sounds get the same gentle note a collection gives them.
  private func attemptPlay(at index: Int) {
    guard entries.indices.contains(index) else { return }
    if isLocked(entries[index]) {
      showPremiumGate = true
    } else {
      player.play(entries.map(\.queueEntry), at: index)
    }
  }
}

#Preview("Playlist — saved sounds") {
  PlaylistView(bottomInset: .rhythm)
    .environment(\.playlistStore, .sample)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
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
