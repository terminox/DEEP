import SwiftUI

/// A single square artwork tile used inside the home's "Made for you" carousel.
/// The GlobalPause twin of DeepSound's `CollectionTile` — same shape and rhythm
/// (square artwork over a title and a secondary line) so the two homes' carousels
/// read identically. Tapping the tile body routes to detail via `openHomeItem`;
/// the play button starts the sound in place.
struct HomeTile: View {
  @Environment(\.openHomeItem) private var openHomeItem
  @Environment(\.soundPlayer) private var player
  let item: HomeItem
  var size: CGFloat = 150

  var body: some View {
    Button {
      openHomeItem(item)
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HomeArtwork(palette: item.palette, imageURL: item.imageURL)
          .frame(width: size, height: size)
          .overlay(alignment: .bottomTrailing) { playButton }
          .shadow(color: Color.lavenderMist.opacity(0.2), radius: 12, x: 0, y: 8)

        VStack(alignment: .leading, spacing: 2) {
          Text(item.title)
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(.deepPlum)
            .lineLimit(1)
          Text(item.author)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .lineLimit(1)
        }
        .frame(width: size, alignment: .leading)
      }
    }
    .buttonStyle(.softPress)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(item.title), \(item.kind.label), \(item.durationLabel)")
  }

  private var playButton: some View {
    Button {
      player.play(item.asSoundCollection)
    } label: {
      Image(systemName: "play.fill")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.deepPlum)
        .frame(width: 36, height: 36)
        .background(.white.opacity(0.9), in: Circle())
        .shadow(color: .deepPlum.opacity(0.2), radius: 6, x: 0, y: 3)
    }
    .buttonStyle(.softPress)
    .padding(8)
    .accessibilityLabel("Play \(item.title)")
  }
}

#Preview("Home Tile") {
  HStack(spacing: 16) {
    ForEach(HomeLibrary.recommended) { HomeTile(item: $0) }
  }
  .padding()
  .background { AtmosphereBackground() }
  .environment(\.openHomeItem, { _ in })
  .environment(\.soundPlayer, MockSoundPlayer.idle)
}
