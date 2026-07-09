import SwiftUI

/// The album-style detail page: a large header with artwork, title, metadata,
/// Play / Shuffle actions, then the track list.
struct CollectionDetailView: View {
  @Environment(\.soundPlayer) private var player
  let collection: SoundCollection
  var bottomInset: CGFloat

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
  }

  private var artworkHeader: some View {
    VStack(spacing: 16) {
      SoundArtwork(palette: collection.palette, cornerRadius: 24)
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
      actionButton(title: "Play", systemName: "play.fill") {
        player.play(collection)
      }
      actionButton(title: "Shuffle", systemName: "shuffle") {
        let start = Int.random(in: 0..<max(1, collection.trackCount))
        player.play(collection, at: start)
      }
    }
    .padding(.horizontal, .edge)
  }

  private func actionButton(
    title: String,
    systemName: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: systemName)
          .font(.system(.subheadline, weight: .semibold))
        Text(title)
          .font(DeepType.body.weight(.medium))
      }
      .foregroundStyle(.deepPlum)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 13)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(.white.opacity(0.55))
          .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .fill(.ultraThinMaterial)
          )
      )
    }
    .buttonStyle(.softPress)
  }

  private var trackList: some View {
    VStack(spacing: 0) {
      ForEach(Array(collection.tracks.enumerated()), id: \.element.id) { pair in
        let (offset, track) = pair
        TrackRow(
          number: offset + 1,
          track: track,
          isCurrent: isCurrent(track)
        ) {
          player.play(collection, at: offset)
        }
        if offset < collection.tracks.count - 1 {
          Divider()
            .overlay(Color.driftGrey.opacity(0.18))
            .padding(.leading, 52)
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
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        Text("\(number)")
          .font(DeepType.body)
          .monospacedDigit()
          .foregroundStyle(.driftGrey)
          .frame(width: 24, alignment: .center)
        Text(track.title)
          .font(DeepType.body.weight(isCurrent ? .semibold : .regular))
          .foregroundStyle(isCurrent ? .lavenderMist : .deepPlum)
          .lineLimit(1)
        Spacer()
        Text(track.duration.clockString)
          .font(DeepType.caption)
          .monospacedDigit()
          .foregroundStyle(.driftGrey)
      }
      .padding(.vertical, 14)
      .contentShape(Rectangle())
    }
    .buttonStyle(.softPress)
  }
}

#Preview("Collection Detail") {
  NavigationStack {
    CollectionDetailView(
      collection: SoundLibrary.sleep[0],
      bottomInset: .rhythm
    )
    .environment(\.soundPlayer, MockSoundPlayer.idle)
  }
}
