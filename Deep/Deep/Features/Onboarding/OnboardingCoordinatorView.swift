import SwiftUI

/// Composition root for the first-run onboarding flow. Like the app's other
/// coordinators it owns a single `NavigationPath`, routes via
/// `.navigationDestination(for:)`, and exposes navigation to its leaf screens
/// through `@Entry` actions — leaf screens never host a `NavigationLink`.
///
/// Styling stays minimal here: each leaf screen draws its own
/// `AtmosphereBackground`, so nothing is hidden behind the `NavigationStack`.
struct OnboardingCoordinatorView: View {
  @Environment(\.onboardingStore) private var store

  @State private var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      OnboardingIntroView()
        .navigationDestination(for: OnboardingRoute.self) { route in
          destination(for: route)
            // Onboarding is a forward-only ritual — no back button anywhere,
            // and the swipe-back pop is disabled with it. Centralised here so
            // every pushed screen is covered uniformly.
            .navigationBarBackButtonHidden(true)
        }
    }
    .tint(.lavenderMist)
    .environment(\.onboardingAdvance, { route in path.append(route) })
    .environment(\.onboardingFinish, { store.completeOnboarding() })
    .preferredColorScheme(.light)
  }

  @ViewBuilder
  private func destination(for route: OnboardingRoute) -> some View {
    switch route {
    case .quiz(let index): OnboardingQuizView(index: index)
    case .mindTree: MindTreePickerView()
    case .craftingSpace: CraftingSpaceView()
    }
  }
}

#Preview("Onboarding — Full flow") {
  OnboardingCoordinatorView()
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
}
