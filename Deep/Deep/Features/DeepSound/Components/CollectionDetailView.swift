import SwiftUI

/// The album-style detail page: a large header with artwork, title, metadata,
/// Play / Shuffle actions, then the track list.
struct CollectionDetailView: View {
  @Environment(\.soundPlayer) private var player
  @Environment(\.premiumAccess) private var premiumAccess
  @Environment(\.playlistStore) private var playlistStore
  @Environment(\.soundContentRepository) private var repository
  @Environment(\.openPaywall) private var openPaywall
  /// The collection as it arrived from the screen that opened it.
  let collection: SoundCollection
  var bottomInset: CGFloat

  /// The collection re-fetched after the listener's DEEP Premium answer
  /// flipped — the copy that arrived carries the server's verdicts (and its
  /// withheld audio) from before the flip.
  @State private var latest: SoundCollection?

  /// What this screen shows and plays: the fresh copy once there is one.
  private var current: SoundCollection { latest ?? collection }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: .rhythm) {
        artworkHeader
        actions
        trackList
        Color.clear.frame(height: bottomInset)
      }
      .padding(.top, 12)
    }
    .scrollBounceBehavior(.basedOnSize)
    .background { AtmosphereBackground() }
    .navigationTitle(current.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .onChange(of: premiumAccess.contentEpoch) {
      Task {
        // A failed fetch keeps the copy on screen; the gate still reads the
        // new answer, so locks follow the flip either way.
        if let fresh = try? await repository.collection(id: collection.id) {
          latest = fresh
        }
      }
    }
  }

  private func isLocked(_ track: SoundTrack) -> Bool {
    PremiumGate.isLocked(track, in: current, hasPremium: premiumAccess.hasPremium)
  }

  /// The tracks this listener can play, in order. Play, Shuffle and a tapped
  /// row all queue these, so a run never carries on into a locked sound.
  private var playable: [SoundQueueEntry] {
    PremiumGate.playable(current, hasPremium: premiumAccess.hasPremium)
  }

  /// Play through the premium gate: a locked sound — or one whose audio the
  /// server withheld — opens the invitation instead of starting.
  private func attemptPlay(at index: Int) {
    guard current.tracks.indices.contains(index) else { return }
    let track = current.tracks[index]
    if !PremiumGate.canStart(track, in: current, hasPremium: premiumAccess.hasPremium) {
      openPaywall(.lockedSound)
    } else {
      let queue = playable
      player.play(queue, at: queue.firstIndex { $0.track.id == track.id } ?? 0)
    }
  }

  /// Play sets off from the first track in order; Shuffle deals the whole
  /// collection in a random order.
  private func playAll(shuffled: Bool) {
    guard !current.tracks.isEmpty else { return }
    let queue = playable
    if queue.isEmpty {
      openPaywall(.lockedSound)
    } else {
      player.play(queue, at: shuffled ? nil : 0, shuffled: shuffled)
    }
  }

  private var artworkHeader: some View {
    VStack(spacing: 16) {
      SoundArtwork(palette: current.palette, imageURL: current.imageURL, cornerRadius: 24)
        .frame(width: 220, height: 220)
        .shadow(color: Color.lavenderMist.opacity(0.35), radius: 28, x: 0, y: 16)

      VStack(spacing: 4) {
        Text(current.title)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .multilineTextAlignment(.center)
        Text(current.subtitle)
          .font(DeepType.body)
          .foregroundStyle(.driftGrey)
          .multilineTextAlignment(.center)
        Text("\(current.trackCount) tracks, \(current.totalDuration.minutesString)")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .padding(.top, 2)
      }
    }
    .padding(.horizontal, .edge)
  }

  private var actions: some View {
    HStack(spacing: 12) {
      SoundActionButton(title: "Play", systemName: "play.fill") {
        playAll(shuffled: false)
      }
      SoundActionButton(title: "Shuffle", systemName: "shuffle") {
        playAll(shuffled: true)
      }
    }
    .padding(.horizontal, .edge)
  }

  private var trackList: some View {
    VStack(spacing: 0) {
      ForEach(Array(current.tracks.enumerated()), id: \.element.id) { pair in
        let (offset, track) = pair
        TrackRow(
          number: offset + 1,
          track: track,
          isCurrent: isCurrent(track),
          isLocked: isLocked(track),
          isSaved: playlistStore.isSaved(track),
          save: { playlistStore.toggle(track, from: current) }
        ) {
          attemptPlay(at: offset)
        }
      }
    }
    .padding(.horizontal, .edge)
  }

  private func isCurrent(_ track: SoundTrack) -> Bool {
    player.collection?.id == collection.id && player.currentTrack?.id == track.id
  }
}

private struct TrackRow: View {
  let number: Int
  let track: SoundTrack
  let isCurrent: Bool
  var isLocked: Bool = false
  /// Whether this sound is already in the listener's playlist — the long-press
  /// menu is the only place a collection offers to save one, so the row itself
  /// stays as quiet as it was.
  var isSaved: Bool = false
  var save: () -> Void = {}
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        Text(verbatim: "\(number)")
          .font(DeepType.body)
          .monospacedDigit()
          .foregroundStyle(.driftGrey)
          .frame(width: 24, alignment: .center)
        Text(track.title)
          .font(DeepType.body.weight(isCurrent ? .semibold : .regular))
          .foregroundStyle(isCurrent ? .lavenderMist : .deepPlum)
          .lineLimit(1)
        Spacer()
        if isLocked {
          PremiumLockBadge(diameter: 22)
            .transition(.opacity)
        }
        Text(track.duration.clockString)
          .font(DeepType.caption)
          .monospacedDigit()
          .foregroundStyle(.driftGrey)
      }
      .padding(.vertical, 14)
      .contentShape(Rectangle())
      .animation(.settle, value: isLocked)
    }
    .buttonStyle(.softPress)
    .contextMenu {
      Button(action: save) {
        Label(
          isSaved ? "Remove from playlist" : "Save to playlist",
          systemImage: isSaved ? "bookmark.slash" : "bookmark"
        )
      }
    }
  }
}

#if DEBUG
#Preview("Collection Detail") {
  NavigationStack {
    CollectionDetailView(
      collection: SoundLibrary.sleep[0],
      bottomInset: .rhythm
    )
    .environment(\.soundPlayer, MockSoundPlayer.idle)
    .environment(\.premiumAccess, .free)
  }
}

#Preview("Collection Detail — locked") {
  NavigationStack {
    CollectionDetailView(
      collection: SoundLibrary.premiumSample,
      bottomInset: .rhythm
    )
    .environment(\.soundPlayer, MockSoundPlayer.idle)
    .environment(\.premiumAccess, .free)
  }
}

#Preview("Collection Detail — member") {
  NavigationStack {
    CollectionDetailView(
      collection: SoundLibrary.premiumSample,
      bottomInset: .rhythm
    )
    .environment(\.soundPlayer, MockSoundPlayer.idle)
    .environment(\.premiumAccess, .member)
  }
}
#endif
