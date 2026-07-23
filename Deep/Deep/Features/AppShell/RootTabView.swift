import SwiftUI

/// Bridges the UIKit `MainTabController` into the SwiftUI app entry point.
///
/// The shared stores + Deep Sound dependencies are passed down explicitly: the
/// tab shell's hosting controllers don't inherit the SwiftUI environment across
/// the UIKit boundary, so the Profile tab (sign-out / onboarding reset) and the
/// Sounds tab (content + player) act on the same instances `AppRootView` owns.
struct RootTabView: UIViewControllerRepresentable {
  let onboardingStore: any OnboardingProgressStore
  let accountStore: any AccountStore
  let subscriptionStore: any SubscriptionStore
  let soundRepository: any SoundContentRepository
  let soundPlayer: any SoundPlaying
  let practiceStore: any PracticeStore
  let heartLedger: HeartLedger

  func makeUIViewController(context: Context) -> MainTabController {
    MainTabController(
      onboardingStore: onboardingStore,
      accountStore: accountStore,
      subscriptionStore: subscriptionStore,
      soundRepository: soundRepository,
      soundPlayer: soundPlayer,
      practiceStore: practiceStore,
      heartLedger: heartLedger
    )
  }

  func updateUIViewController(_ controller: MainTabController, context: Context) {}
}

#Preview {
  RootTabView(
    onboardingStore: OnboardingProgressDefaultsStore(),
    accountStore: PreviewAccountStore(),
    subscriptionStore: PreviewSubscriptionStore(),
    soundRepository: FixtureSoundContentRepository(),
    soundPlayer: SoundPlayer(),
    practiceStore: MockPracticeStore(),
    heartLedger: .sample
  )
  .ignoresSafeArea()
}
