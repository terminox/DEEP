import SwiftUI

/// The docked player that rides above the home content. Tapping anywhere
/// (other than the transport buttons) expands into Now Playing; the artwork
/// morphs across via `matchedGeometryEffect`.
struct MiniPlayerBar: View {
  @Environment(SoundPlayer.self) private var player
  var artworkNamespace: Namespace.ID
  var onExpand: () -> Void

  var body: some View {
    let track = player.currentTrack

    Button(action: onExpand) {
      HStack(spacing: 12) {
        SoundArtwork(palette: player.collection?.palette ?? .mist, cornerRadius: 10)
          .frame(width: 44, height: 44)
          .matchedGeometryEffect(id: SoundPlayerNamespace.artwork, in: artworkNamespace)

        VStack(alignment: .leading, spacing: 2) {
          Text(track?.title ?? "Not playing")
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(DeepColor.deepPlum)
            .lineLimit(1)
          Text(player.collection?.title ?? "")
            .font(DeepType.caption)
            .foregroundStyle(DeepColor.driftGrey)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        transportButton(
          systemName: player.isPlaying ? "pause.fill" : "play.fill",
          size: 20
        ) {
          player.togglePlayPause()
        }

        transportButton(systemName: "forward.fill", size: 18) {
          player.next()
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .background(miniBackground)
      .overlay(alignment: .bottom) { progressLine }
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.softPress)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Now playing \(player.currentTrack?.title ?? ""). Tap to open the player.")
  }

  private var miniBackground: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(.ultraThinMaterial)
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(.white.opacity(0.4))
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
    }
    .shadow(color: DeepColor.lavenderMist.opacity(0.25), radius: 18, x: 0, y: 8)
  }

  private var progressLine: some View {
    GeometryReader { geo in
      Capsule()
        .fill(DeepColor.lavenderMist.opacity(0.7))
        .frame(width: geo.size.width * player.progress, height: 2)
    }
    .frame(height: 2)
    .padding(.horizontal, 10)
    .padding(.bottom, 3)
  }

  private func transportButton(
    systemName: String,
    size: CGFloat,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: size, weight: .medium))
        .foregroundStyle(DeepColor.deepPlum)
        .frame(width: 40, height: 40)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
