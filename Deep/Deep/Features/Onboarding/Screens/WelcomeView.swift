import SwiftUI

/// A single, quiet welcome beat — the user's name, gently. Mirrors the Calm
/// reference's "Welcome to Calm Sleep, Alex." moment, in Deep's serif voice.
/// Auto-blooms in, then offers a soft continue to the paywall.
struct WelcomeView: View {
  @Environment(\.accountStore) private var accountStore
  @Environment(\.onboardingAdvance) private var advance
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var appeared = false

  private var name: String { accountStore.account?.displayName ?? "friend" }

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(spacing: .rhythm) {
        Spacer()

        Text("Welcome to Deep,\n\(name).")
          .font(DeepType.wordmark)
          .foregroundStyle(.deepPlum)
          .multilineTextAlignment(.center)
          .opacity(appeared ? 1 : 0)
          .scaleEffect(appeared || reduceMotion ? 1 : 0.94)
          .padding(.horizontal, .edge)

        Spacer()

        OnboardingPrimaryButton(title: "Continue") {
          advance(.paywall)
        }
        .opacity(appeared ? 1 : 0)
        .padding(.horizontal, .edge)
        .padding(.bottom, .rhythm)
      }
    }
    .navigationBarBackButtonHidden(true)
    .onAppear {
      withAnimation(.bloom.delay(0.15)) { appeared = true }
    }
  }
}

#Preview("Onboarding — Welcome") {
  WelcomeView()
    .environment(\.accountStore, MockAccountStore.emailUser)
}
