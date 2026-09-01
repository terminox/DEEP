import SwiftUI

/// The opening of onboarding — a sunrise over a still mountain lake, looping
/// softly behind the logo. Moon-cream veils keep the logo and actions
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

  /// Where the server-driven onboarding config has got to. The whole flow is
  /// server-driven from its very first question, so "Begin" stays dimmed until
  /// the config lands and turns into a retry if the fetch gives up — the screen
  /// never pretends to be ready over content that isn't there.
  enum ConfigState {
    case loading
    case ready
    case failed
  }

  var videoMode: VideoMode = .live()
  var configState: ConfigState = .ready
  /// Re-runs the config fetch, from the `.failed` CTA.
  var onRetry: () -> Void = {}

  @Environment(\.onboardingAdvance) private var advance
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  private var isStill: Bool {
    if case .still = videoMode { return true }
    return false
  }

  /// Increase Contrast flattens the veils to solid moon cream, which is also
  /// the mark's own colour — so the mark trades its cream bloom for a solid
  /// tint rather than disappearing into the backdrop.
  private var increasedContrast: Bool { contrast == .increased }

  var body: some View {
    ZStack {
      // The still mode renders inside the ripple's `layerEffect`; a driftless
      // atmosphere lets that layer rasterize once instead of every frame.
      AtmosphereBackground(animated: !isStill)

      video
        .ignoresSafeArea()
        .accessibilityHidden(true)

      veils

      VStack(spacing: .rhythm) {
        DeepLogoMark(
          size: 80,
          tint: increasedContrast ? .irisDusk : .moonCream,
          isGlowing: !increasedContrast
        )

        Image("OnboardingLogoText")
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(.irisDusk)
          .frame(maxWidth: 300)
          .accessibilityAddTraits(.isHeader)
          .accessibilityLabel("DEEP — peace begins within")
          .shadow(color: .moonCream.opacity(0.8), radius: 12)

        Spacer(minLength: 0)

        VStack(spacing: 14) {
          if configState == .failed {
            Text("We couldn't reach Deep just now.")
              .font(DeepType.caption)
              .foregroundStyle(.driftGrey)
              .multilineTextAlignment(.center)

            OnboardingPrimaryButton(title: "Try again", action: onRetry)
          } else {
            OnboardingPrimaryButton(title: "Begin", isEnabled: configState == .ready) {
              advance(.quiz(index: 0))
            }
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
        .animation(.exhale, value: configState)
      }
      .padding(.horizontal, .edge)
      // The mark's halo needs room off the status bar — without it the ring
      // sits against the Dynamic Island.
      .padding(.vertical, .rhythm)
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
  /// footage: a light wash over the sky behind the logo, and a near-solid
  /// scrim under the actions. Both go solid when Increase Contrast is on.
  private var veils: some View {
    VStack(spacing: 0) {
      LinearGradient(
        colors: [Color.moonCream.opacity(increasedContrast ? 1 : 0.55), .clear],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(maxHeight: .infinity)

      Spacer(minLength: 0)
        .frame(maxHeight: .infinity)

      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: Color.moonCream.opacity(increasedContrast ? 1 : 0.85), location: 0.55),
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

#Preview("Onboarding — Welcome, config loading") {
  OnboardingIntroView(configState: .loading)
}

#Preview("Onboarding — Welcome, config failed") {
  OnboardingIntroView(configState: .failed, onRetry: {})
}
