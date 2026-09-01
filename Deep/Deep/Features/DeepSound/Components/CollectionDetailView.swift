import SwiftUI

/// The album-style detail page: a large header with artwork, title, metadata,
/// Play / Shuffle actions, then the track list.
struct CollectionDetailView: View {
  @Environment(\.soundPlayer) private var player
  @Environment(\.subscriptionStore) private var subscriptionStore
  @Environment(\.playlistStore) private var playlistStore
  let collection: SoundCollection
  var bottomInset: CGFloat

  @State private var showPremiumGate = false

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
    .navigationTitle(collection.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .alert("A premium sound", isPresented: $showPremiumGate) {
      Button("Maybe later", role: .cancel) {}
    } message: {
      Text("This one is part of DEEP Premium. It'll be here whenever you're ready.")
    }
  }

  private func isLocked(_ track: SoundTrack) -> Bool {
    (collection.isPremium || track.isPremium) && !subscriptionStore.isSubscribed
  }

  /// Play through the premium gate: locked content shows a gentle note instead.
  private func attemptPlay(at index: Int) {
    guard collection.tracks.indices.contains(index) else { return }
    if isLocked(collection.tracks[index]) {
      showPremiumGate = true
    } else {
      player.play(collection, at: index)
    }
  }

  private var artworkHeader: some View {
    VStack(spacing: 16) {
      SoundArtwork(palette: collection.palette, imageURL: collection.imageURL, cornerRadius: 24)
        .frame(width: 220, height: 220)
        .shadow(color: Color.lavenderMist.opacity(0.35), radius: 28, x: 0, y: 16)

      VStack(spacing: 4) {
        Text(collection.title)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .multilineTextAlignment(.center)
        Text(collection.subtitle)
          .font(DeepType.body)
          .foregroundStyle(.driftGrey)
          .multilineTextAlignment(.center)
        Text("\(collection.trackCount) tracks · \(collection.totalDuration.minutesString)")
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
        attemptPlay(at: 0)
      }
      SoundActionButton(title: "Shuffle", systemName: "shuffle") {
        let start = Int.random(in: 0..<max(1, collection.trackCount))
        attemptPlay(at: start)
      }
    }
    .padding(.horizontal, .edge)
  }

  private var trackList: some View {
    VStack(spacing: 0) {
      ForEach(Array(collection.tracks.enumerated()), id: \.element.id) { pair in
        let (offset, track) = pair
        TrackRow(
          number: offset + 1,
          track: track,
          isCurrent: isCurrent(track),
          isLocked: isLocked(track),
          isSaved: playlistStore.isSaved(track),
          save: { playlistStore.toggle(track, from: collection) }
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
          Image(systemName: "lock.fill")
            .font(.caption)
            .foregroundStyle(.driftGrey)
        }
        Text(track.duration.clockString)
          .font(DeepType.caption)
          .monospacedDigit()
          .foregroundStyle(.driftGrey)
      }
      .padding(.vertical, 14)
      .contentShape(Rectangle())
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
  }
}
#endif
