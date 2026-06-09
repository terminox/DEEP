import SwiftUI

/// The docked player that rides above the home content, finished in iOS 26
/// Liquid Glass like Apple Music's mini player. Tapping anywhere (other than the
/// transport buttons) expands into Now Playing; the artwork morphs across via
/// `matchedGeometryEffect`.
struct MiniPlayerBar: View {
  @Environment(\.soundPlayer) private var player
  var artworkNamespace: Namespace.ID
  var onExpand: () -> Void

  private let shape = RoundedRectangle(cornerRadius: .card, style: .continuous)

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
            .foregroundStyle(.deepPlum)
            .lineLimit(1)
          Text(player.collection?.title ?? "")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
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
      .padding(.horizontal, 14)
      .padding(.vertical, 9)
      .modifier(LiquidGlassBar(shape: shape))
      .overlay(alignment: .bottom) { progressLine }
      .contentShape(shape)
      .shadow(color: Color.lavenderMist.opacity(0.22), radius: 16, x: 0, y: 8)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Now playing \(player.currentTrack?.title ?? ""). Tap to open the player.")
  }

  private var progressLine: some View {
    GeometryReader { geo in
      Capsule()
        .fill(Color.lavenderMist.opacity(0.7))
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
        .foregroundStyle(.deepPlum)
        .frame(width: 40, height: 40)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

/// Finishes the mini player in iOS 26 Liquid Glass — the adaptive,
/// self-illuminating material Apple Music's mini player rides on. `interactive()`
/// lets the glass react fluidly to touch, so the bar itself is the press
/// affordance. On iOS 18–25 it falls back to a hand-blended frosted material so
/// the bar still reads as glass.
private struct LiquidGlassBar: ViewModifier {
  let shape: RoundedRectangle

  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular.interactive(), in: shape)
    } else {
      content.background(fallback)
    }
  }

  private var fallback: some View {
    ZStack {
      shape.fill(.ultraThinMaterial)
      shape.fill(.white.opacity(0.4))
      shape.strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
    }
  }
}

#if DEBUG
/// Hosts the `@Namespace` the bar needs for its matched-geometry artwork.
private struct MiniPlayerBarPreviewHost: View {
  @Namespace private var artworkNamespace
  let player: SoundPlaying

  var body: some View {
    MiniPlayerBar(artworkNamespace: artworkNamespace) {}
      .environment(\.soundPlayer, player)
      .padding(.horizontal, .edge)
  }
}

#Preview("Mini Player — Playing") {
  MiniPlayerBarPreviewHost(player: MockSoundPlayer.playing)
    .frame(maxHeight: .infinity)
    .background { AtmosphereBackground() }
}

#Preview("Mini Player — Idle") {
  MiniPlayerBarPreviewHost(player: MockSoundPlayer.idle)
    .frame(maxHeight: .infinity)
    .background { AtmosphereBackground() }
}
#endif
