import SwiftUI

/// A single square artwork tile used inside the home's "Made for you" carousel.
/// The GlobalPause twin of DeepSound's `CollectionTile` — same shape and rhythm
/// (square artwork over a title and a secondary line) so the two homes' carousels
/// read identically. Tapping the tile body pushes the collection detail via
/// `openCollection`; the play button starts the collection in place.
struct HomeTile: View {
  @Environment(\.openCollection) private var openCollection
  @Environment(\.soundPlayer) private var player
  @Environment(\.premiumAccess) private var premiumAccess
  @Environment(\.openPaywall) private var openPaywall
  let collection: SoundCollection
  var size: CGFloat = 150

  var body: some View {
    Button {
      openCollection(collection)
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        SoundArtwork(palette: collection.palette, imageURL: collection.imageURL)
          .frame(width: size, height: size)
          .premiumLockBadge(PremiumGate.isLocked(collection, hasPremium: premiumAccess.hasPremium))
          .overlay(alignment: .bottomTrailing) { playButton }
          .shadow(color: Color.lavenderMist.opacity(0.2), radius: 12, x: 0, y: 8)

        VStack(alignment: .leading, spacing: 2) {
          Text(collection.title)
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(.deepPlum)
            .lineLimit(1)
          Text(collection.subtitle)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .lineLimit(1)
        }
        .frame(width: size, alignment: .leading)
      }
    }
    .buttonStyle(.softPress)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(collection.title), \(collection.kindLabel), \(collection.totalDuration.minutesString)")
  }

  private var playButton: some View {
    Button {
      // Through the gate, like a collection's own Play: only what this
      // listener may hear is queued, and nothing to hear opens the invitation.
      let queue = PremiumGate.playable(collection, hasPremium: premiumAccess.hasPremium)
      if queue.isEmpty {
        openPaywall(.lockedSound)
      } else {
        player.play(queue, at: 0)
      }
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
    .accessibilityLabel("Play \(collection.title)")
  }
}

#if DEBUG
#Preview("Home Tile") {
  HStack(spacing: 16) {
    ForEach(Array(SoundLibrary.morning.prefix(2))) { HomeTile(collection: $0) }
  }
  .padding()
  .background { AtmosphereBackground() }
  .environment(\.openCollection, { _ in })
  .environment(\.soundPlayer, MockSoundPlayer.idle)
  .environment(\.premiumAccess, .free)
}

#Preview("Home Tile — locked") {
  HStack(spacing: 16) {
    HomeTile(collection: SoundLibrary.morning[0])
    HomeTile(collection: SoundLibrary.premiumSample)
  }
  .padding()
  .background { AtmosphereBackground() }
  .environment(\.openCollection, { _ in })
  .environment(\.soundPlayer, MockSoundPlayer.idle)
  .environment(\.premiumAccess, .free)
}
#endif
