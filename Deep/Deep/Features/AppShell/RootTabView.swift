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
  let gardenStore: GardenStore
  let playlistStore: PlaylistStore
  let continuityWitness: ContinuityWitness
  let pauseSession: GlobalPauseSession
  let pauseRepository: any PauseEventRepository
  let imageLoader: any ImageLoading
  let videoCache: VideoCache?

  func makeUIViewController(context: Context) -> MainTabController {
    MainTabController(
      onboardingStore: onboardingStore,
      accountStore: accountStore,
      subscriptionStore: subscriptionStore,
      soundRepository: soundRepository,
      soundPlayer: soundPlayer,
      practiceStore: practiceStore,
      heartLedger: heartLedger,
      gardenStore: gardenStore,
      playlistStore: playlistStore,
      continuityWitness: continuityWitness,
      pauseSession: pauseSession,
      pauseRepository: pauseRepository,
      imageLoader: imageLoader,
      videoCache: videoCache
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
    heartLedger: .sample,
    gardenStore: .sample,
    playlistStore: .sample,
    continuityWitness: .unwitnessed,
    pauseSession: GlobalPauseSession(
      clock: SyncedClock(),
      repository: FixturePauseEventRepository()
    ),
    pauseRepository: FixturePauseEventRepository(),
    imageLoader: FixtureImageLoader(),
    videoCache: nil
  )
  .ignoresSafeArea()
}
