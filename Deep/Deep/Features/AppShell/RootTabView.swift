import SwiftUI

/// Bridges the UIKit `MainTabController` into the SwiftUI app entry point.
///
/// The shared onboarding/account stores are passed down so the Profile tab can
/// drive sign-out and onboarding reset on the *same* instances `AppRootView`
/// watches — the tab shell's hosting controllers don't inherit the SwiftUI
/// environment across the UIKit boundary, so we inject explicitly.
struct RootTabView: UIViewControllerRepresentable {
  let onboardingStore: any OnboardingProgressStore
  let accountStore: any AccountStore

  func makeUIViewController(context: Context) -> MainTabController {
    MainTabController(onboardingStore: onboardingStore, accountStore: accountStore)
  }

  func updateUIViewController(_ controller: MainTabController, context: Context) {}
}

#Preview {
  RootTabView(
    onboardingStore: OnboardingProgressDefaultsStore(),
    accountStore: KeychainlessAccountStore()
  )
  .ignoresSafeArea()
}
