import SwiftUI

/// Optional "how did you find us" — kept genuinely optional (a quiet "Skip"
/// alongside Continue). Adapted from the Calm reference's "How did you hear about
/// Calm Sleep?" screen. Records the choice, then heads to account creation.
struct ReferralSourceView: View {
  @Environment(\.onboardingStore) private var store
  @Environment(\.onboardingAdvance) private var advance

  private let sources = [
    "A friend or family",
    "The App Store",
    "Social media",
    "A podcast or article",
    "Somewhere else",
  ]

  @State private var selected: String?

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(alignment: .leading, spacing: .rhythm) {
        Text("How did you find Deep?")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .padding(.top, 8)

        ScrollView {
          VStack(spacing: 12) {
            ForEach(sources, id: \.self) { source in
              QuizOptionCard(
                option: QuizOption(id: source, title: source, palette: .mist),
                isSelected: selected == source
              ) {
                withAnimation(.settle) { selected = source }
              }
            }
          }
          .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)

        VStack(spacing: 6) {
          OnboardingPrimaryButton(title: "Continue") {
            store.setReferralSource(selected)
            advance(.auth)
          }
          OnboardingGhostButton(title: "Skip") {
            store.setReferralSource(nil)
            advance(.auth)
          }
        }
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationBarBackButtonHidden(true)
    .onAppear { selected = store.state.referralSource }
  }
}

#Preview("Onboarding — Referral") {
  ReferralSourceView()
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
}
