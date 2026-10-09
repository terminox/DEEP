#if DEBUG
import SwiftUI

/// THROWAWAY. D · Sky title — Pillow / Oura.
///
/// The photograph runs edge to edge. The title moves to the top-left, a large
/// serif headline over the sky, and every control gathers into one compact
/// glass capsule floating near the bottom, so the middle of the image is left
/// entirely clear.
struct SkyTitleNowPlaying: View {
  var onDismiss: () -> Void

  @Environment(\.soundPlayer) private var player
  @State private var showLyrics = false

  var body: some View {
    ZStack {
      LabArtwork()
        .ignoresSafeArea()

      VStack(spacing: 0) {
        LabScrim(edge: .top, peak: 0.7)
          .frame(height: 340)
        Spacer()
        LabScrim(edge: .bottom, peak: 0.5)
          .frame(height: 240)
      }
      .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 0) {
        HStack {
          LabDismissButton(ink: .onPhoto, action: onDismiss)
          Spacer()
        }
        .padding(.top, 4)

        headline
          .padding(.top, 20)

        Spacer(minLength: 0)

        HStack {
          Spacer()
          LabIconButton(systemName: "text.quote", ink: .onPhoto, glass: true, label: "Lyrics") {
            showLyrics = true
          }
        }
        .padding(.bottom, 12)

        capsule
      }
      .padding(.horizontal, .edge)
    }
    .labLyrics(isPresented: $showLyrics)
  }

  private var headline: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 8) {
        Text((player.collection?.title ?? "").uppercased())
          .font(DeepType.micro)
          .tracking(1.6)
          .foregroundStyle(LabInk.onPhoto.secondary)
        Text(player.currentTrack?.title ?? "")
          .font(.system(size: 44, weight: .light, design: .serif))
          .foregroundStyle(LabInk.onPhoto.primary)
          .lineLimit(3)
          .minimumScaleFactor(0.7)
        Text(player.duration.minutesString)
          .font(DeepType.caption)
          .foregroundStyle(LabInk.onPhoto.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      LabSaveButton(ink: .onPhoto)
    }
  }

  private var capsule: some View {
    VStack(spacing: 2) {
      // Glass reads pale over any photo, so the capsule wears plum ink — the
      // frosted-panel look — with the cream play disc as its one bright spot.
      LabScrubber(ink: .onPale)
      HStack(spacing: 36) {
        LabSkipButton(direction: .back, ink: .onPale, size: 22)
        LabPlayButton(ink: .onPhoto, diameter: 56)
        LabSkipButton(direction: .forward, ink: .onPale, size: 22)
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 10)
    .padding(.bottom, 14)
    .modifier(LabCapsuleGlass())
    .padding(.bottom, 8)
  }
}

/// Liquid Glass in a large rounded rectangle, frosted before iOS 26.
private struct LabCapsuleGlass: ViewModifier {
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular, in: shape)
    } else {
      content.background(shape.fill(.ultraThinMaterial))
    }
  }
}

#Preview("D · Sky title") {
  SkyTitleNowPlaying {}
    .environment(\.soundPlayer, MockSoundPlayer.playing)
}
#endif
