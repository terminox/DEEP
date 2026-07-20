import SwiftUI

/// The opening of onboarding — a glowing, breathing welcome. A soft aura of
/// light rings a heart above the wordmark and tagline; one calm invitation to
/// begin. The aura breathes on a slow cycle, stilled when Reduce Motion is on.
struct OnboardingIntroView: View {
  @Environment(\.onboardingAdvance) private var advance
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var isBreathing = false

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(spacing: .rhythm) {
        Spacer(minLength: 0)

        aura
          .padding(.bottom, 12)

        VStack(spacing: 10) {
          Text("Deep")
            .font(DeepType.wordmark)
            .foregroundStyle(.deepPlum)
          Text("A space to pause,\nbreathe, and reconnect.")
            .font(DeepType.body)
            .foregroundStyle(.driftGrey)
            .multilineTextAlignment(.center)
        }

        Spacer(minLength: 0)

        VStack(spacing: 14) {
          OnboardingPrimaryButton(title: "Begin") {
            advance(.quiz(index: 0))
          }

          Button {
            advance(.logIn)
          } label: {
            Text("I already have an account")
              .font(DeepType.caption)
              .foregroundStyle(.driftGrey)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity)
    }
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
        isBreathing = true
      }
    }
  }

  /// Concentric rings of pastel light around a softly glowing heart.
  private var aura: some View {
    ZStack {
      RadialGradient(
        colors: [Color.lavenderMist.opacity(0.5), Color.blushPowder.opacity(0.22), .clear],
        center: .center,
        startRadius: 10,
        endRadius: 150
      )
      .frame(width: 300, height: 300)

      Circle()
        .strokeBorder(
          AngularGradient(
            colors: [.skyWash, .lavenderMist, .blushPowder, .peachCloud, .skyWash],
            center: .center
          ),
          lineWidth: 2
        )
        .frame(width: 248, height: 248)
        .blur(radius: 0.5)
        .scaleEffect(isBreathing ? 1.05 : 0.98)

      Circle()
        .strokeBorder(.white.opacity(0.7), lineWidth: 1.5)
        .frame(width: 192, height: 192)
        .scaleEffect(isBreathing ? 1.03 : 0.99)

      Circle()
        .fill(
          RadialGradient(
            colors: [.white.opacity(0.9), Color.blushPowder.opacity(0.35), .clear],
            center: .center,
            startRadius: 4,
            endRadius: 95
          )
        )
        .frame(width: 190, height: 190)

      Image(systemName: "heart.fill")
        .font(.system(size: 44))
        .foregroundStyle(.white)
        .shadow(color: .white.opacity(0.85), radius: 16)
        .scaleEffect(isBreathing ? 1.06 : 1.0)
    }
    .accessibilityHidden(true)
  }
}

#Preview("Onboarding — Welcome") {
  OnboardingIntroView()
}
