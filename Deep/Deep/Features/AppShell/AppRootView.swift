import SwiftUI

/// The app's SwiftUI root. It decides between first-run onboarding and the main
/// UIKit-backed tab shell based on a persisted flag, and owns the app-lifetime
/// stores so both onboarding and (later) settings can read them.
///
/// The swap is a `.bloom` crossfade — never a hard cut — in keeping with Deep's
/// motion language. `RootTabView` keeps its `.ignoresSafeArea()` so the UIKit
/// tab bar still fills the screen; onboarding leaf screens manage their own
/// safe-area insets.
struct AppRootView: View {
  @State private var onboardingStore: any OnboardingProgressStore = OnboardingProgressDefaultsStore()
  @State private var accountStore: any AccountStore = KeychainlessAccountStore()
  @State private var subscriptionStore: any SubscriptionStore = StoreKitSubscriptionStore()

  var body: some View {
    ZStack {
      if onboardingStore.hasCompletedOnboarding {
        RootTabView(onboardingStore: onboardingStore, accountStore: accountStore)
          .ignoresSafeArea()
          .transition(.opacity)
      } else {
        OnboardingCoordinatorView()
          .transition(.opacity)
      }
    }
    .animation(.bloom, value: onboardingStore.hasCompletedOnboarding)
    .environment(\.onboardingStore, onboardingStore)
    .environment(\.accountStore, accountStore)
    .environment(\.subscriptionStore, subscriptionStore)
  }
}

#Preview("App root — onboarding") {
  AppRootView()
}
