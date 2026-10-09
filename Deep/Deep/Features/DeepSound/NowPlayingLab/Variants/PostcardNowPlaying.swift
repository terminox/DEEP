#if DEBUG
import SwiftUI

/// THROWAWAY. B · Postcard — TIDE.
///
/// The image is the screen, and the player is the caption on it: a big serif
/// title bottom-left, one glass play button bottom-right, a quiet progress
/// line and an icon row. No time labels, no volume. Tap the image and every
/// control fades away, leaving only the picture.
struct PostcardNowPlaying: View {
  var onDismiss: () -> Void

  @Environment(\.soundPlayer) private var player
  @State private var showLyrics = false
  @State private var chromeHidden = false

  var body: some View {
    ZStack {
      LabArtwork()
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { chromeHidden.toggle() }

      Group {
        VStack(spacing: 0) {
          LabScrim(edge: .top, peak: 0.35)
            .frame(height: 150)
          Spacer()
          LabScrim(edge: .bottom, peak: 0.75)
            .frame(height: 360)
        }
        .ignoresSafeArea()

        VStack(spacing: 0) {
          HStack {
            LabDismissButton(ink: .onPhoto, action: onDismiss)
            Spacer()
          }
          .padding(.top, 4)
          Spacer(minLength: 0)
          caption
        }
        .padding(.horizontal, .edge)
      }
      .opacity(chromeHidden ? 0 : 1)
      .allowsHitTesting(!chromeHidden)
    }
    .animation(.exhale, value: chromeHidden)
    .labLyrics(isPresented: $showLyrics)
  }

  private var caption: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack(alignment: .bottom, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text((player.collection?.title ?? "").uppercased())
            .font(DeepType.micro)
            .tracking(1.6)
            .foregroundStyle(LabInk.onPhoto.secondary)
          Text(player.currentTrack?.title ?? "")
            .font(.system(size: 38, weight: .light, design: .serif))
            .foregroundStyle(LabInk.onPhoto.primary)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
          Text(remaining)
            .font(DeepType.caption)
            .monospacedDigit()
            .foregroundStyle(LabInk.onPhoto.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        LabPlayButton(ink: .onPhoto, diameter: 64, filled: false)
      }

      progressLine

      HStack {
        LabSkipButton(direction: .back, ink: .onPhoto, size: 20)
        Spacer()
        LabSaveButton(ink: .onPhoto)
        Spacer()
        LabIconButton(systemName: "text.quote", ink: .onPhoto, label: "Lyrics") { showLyrics = true }
        Spacer()
        LabSkipButton(direction: .forward, ink: .onPhoto, size: 20)
      }
    }
    .padding(.bottom, 8)
  }

  /// Progress you read, not drag — the postcard has nothing to grab.
  private var progressLine: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(.moonCream.opacity(0.25))
        Capsule()
          .fill(.moonCream)
          .frame(width: geo.size.width * min(1, max(0, player.progress)))
      }
    }
    .frame(height: 3)
  }

  private var remaining: String {
    let left = max(0, player.duration - player.elapsed)
    return "\(left.clockString) left"
  }
}

#Preview("B · Postcard") {
  PostcardNowPlaying {}
    .environment(\.soundPlayer, MockSoundPlayer.playing)
}
#endif
