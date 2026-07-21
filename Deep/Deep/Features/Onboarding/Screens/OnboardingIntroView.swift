import SwiftUI

/// The opening of onboarding — a sunrise over a still mountain lake, looping
/// softly behind the wordmark. Moon-cream veils keep the wordmark and actions
/// legible over the footage; the video stills itself when Reduce Motion is on.
struct OnboardingIntroView: View {
  /// How the sunrise footage renders. `.live` plays the looping video — the
  /// optional grabber lets the coordinator freeze the current frame when a CTA
  /// is tapped. `.still` re-renders the whole screen as pure SwiftUI around
  /// that frozen frame, which is what the ripple transition's Metal shader
  /// dissolves (layer effects can't sample an `AVPlayerLayer`).
  enum VideoMode {
    case live(frameGrabber: LoopingVideoFrameGrabber? = nil)
    case still(frame: UIImage?)
  }

  var videoMode: VideoMode = .live()

  @Environment(\.onboardingAdvance) private var advance
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    ZStack {
      AtmosphereBackground()

      video
        .ignoresSafeArea()
        .accessibilityHidden(true)

      veils

      VStack(spacing: .rhythm) {
        VStack(spacing: 10) {
          Text("Deep")
            .font(DeepType.wordmark)
            .foregroundStyle(.deepPlum)
            .accessibilityAddTraits(.isHeader)
          Text("A space to pause,\nbreathe, and reconnect.")
            .font(DeepType.body)
            .foregroundStyle(.deepPlum)
            .multilineTextAlignment(.center)
        }
        .shadow(color: .moonCream.opacity(0.8), radius: 12)
        .padding(.top, .rhythm * 2)

        Spacer(minLength: 0)

        VStack(spacing: 14) {
          OnboardingPrimaryButton(title: "Begin") {
            advance(.quiz(index: 0))
          }

          Button {
            advance(.logIn)
          } label: {
            (Text("Already have an account? ") + Text("Log in").bold().underline())
              .font(DeepType.caption)
              .foregroundStyle(.deepPlum)
              .frame(minHeight: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity)
    }
  }

  /// The looping footage, or its frozen frame drawn with the same centred
  /// aspect-fill the player layer uses so the two are pixel-aligned. A nil
  /// still frame renders nothing and the atmosphere shows through.
  @ViewBuilder
  private var video: some View {
    switch videoMode {
    case .live(let frameGrabber):
      LoopingVideoView(
        resource: "welcome",
        isAnimating: !reduceMotion,
        playbackRate: 1.0,
        frameGrabber: frameGrabber
      )
    case .still(let frame):
      if let frame {
        GeometryReader { geo in
          Image(uiImage: frame)
            .resizable()
            .scaledToFill()
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
      }
    }
  }

  /// Soft moon-cream gradients that guarantee text contrast against the
  /// footage: a light wash over the sky behind the wordmark, and a near-solid
  /// scrim under the actions. Both go solid when Increase Contrast is on.
  private var veils: some View {
    let increased = contrast == .increased
    return VStack(spacing: 0) {
      LinearGradient(
        colors: [Color.moonCream.opacity(increased ? 1 : 0.55), .clear],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(maxHeight: .infinity)

      Spacer(minLength: 0)
        .frame(maxHeight: .infinity)

      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: Color.moonCream.opacity(increased ? 1 : 0.85), location: 0.55),
          .init(color: .moonCream, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(maxHeight: .infinity)
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }
}

#Preview("Onboarding — Welcome") {
  OnboardingIntroView()
}
