import SwiftUI

/// The mini player content hosted inside the tab bar's bottom accessory — the
/// system Liquid Glass pill above the tab bar (Apple Music's mini player). The
/// system accessory supplies the glass capsule and elevation, so this view is
/// pure content. Tapping anywhere (other than the transport buttons) expands
/// into Now Playing — see `PlayerAccessoryView`.
struct MiniPlayerBar: View {
  @Environment(\.soundPlayer) private var player
  var onExpand: () -> Void

  var body: some View {
    let track = player.currentTrack

    Button(action: onExpand) {
      HStack(spacing: 10) {
        SoundArtwork(palette: player.collection?.palette ?? .mist, cornerRadius: 8)
          .frame(width: 36, height: 36)

        VStack(alignment: .leading, spacing: 1) {
          Text(track?.title ?? "Not playing")
            .font(DeepType.caption.weight(.medium))
            .foregroundStyle(.deepPlum)
            .lineLimit(1)
          Text(player.collection?.title ?? "")
            .font(DeepType.micro)
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
      .padding(.horizontal, 12)
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .overlay(alignment: .bottom) { progressLine }
      // Clip the content and its progress line together to the accessory's
      // capsule silhouette, so the full-width line is trimmed by the same
      // curve the system pill draws.
      .clipShape(Capsule())
      .contentShape(Capsule())
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
  }
}

/// The compact mini player shown while the tab bar is minimized (on scroll) and
/// the accessory rides inline beside it — artwork, title and play/pause only,
/// sized for the narrow pill the system leaves next to the collapsed bar.
struct MiniPlayerInlineBar: View {
  @Environment(\.soundPlayer) private var player
  var onExpand: () -> Void

  var body: some View {
    Button(action: onExpand) {
      HStack(spacing: 10) {
        SoundArtwork(palette: player.collection?.palette ?? .mist, cornerRadius: 7)
          .frame(width: 28, height: 28)

        Text(player.currentTrack?.title ?? "Not playing")
          .font(DeepType.caption)
          .foregroundStyle(.deepPlum)
          .lineLimit(1)

        Spacer(minLength: 4)

        transportButton(
          systemName: player.isPlaying ? "pause.fill" : "play.fill",
          size: 16
        ) {
          player.togglePlayPause()
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Now playing \(player.currentTrack?.title ?? ""). Tap to open the player.")
  }
}

/// Shared transport control for both mini player variants: a bare glyph with a
/// generous tap target that doesn't trigger the surrounding expand button.
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

#if DEBUG
// The shipped bar rides on the system accessory's glass; previews stand that
// chrome in with a plain `glassEffect` capsule so the content reads in context.
#Preview("Mini Player — Playing") {
  MiniPlayerBar {}
    .environment(\.soundPlayer, MockSoundPlayer.playing)
    .glassEffect(.regular, in: Capsule())
    .padding(.horizontal, .edge)
    .frame(maxHeight: .infinity)
    .background { AtmosphereBackground() }
}

#Preview("Mini Player — Idle") {
  MiniPlayerBar {}
    .environment(\.soundPlayer, MockSoundPlayer.idle)
    .glassEffect(.regular, in: Capsule())
    .padding(.horizontal, .edge)
    .frame(maxHeight: .infinity)
    .background { AtmosphereBackground() }
}

#Preview("Mini Player — Inline") {
  MiniPlayerInlineBar {}
    .environment(\.soundPlayer, MockSoundPlayer.playing)
    .glassEffect(.regular, in: Capsule())
    .frame(width: 240)
    .frame(maxHeight: .infinity)
    .background { AtmosphereBackground() }
}
#endif
