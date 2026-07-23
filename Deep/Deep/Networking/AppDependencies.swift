import SwiftUI

/// The app's composition root. Builds the single `APIClient` (base URL from the
/// active `AppConfig`) and the concrete stores/repositories that hang off it,
/// so everything shares one token store and one network seam. `AppRootView`
/// owns one instance and injects its pieces into the environment.
@MainActor
final class AppDependencies {
  let config: AppConfig
  let apiClient: APIClient

  let accountStore: any AccountStore
  let onboardingStore: any OnboardingProgressStore
  let onboardingRemote: any OnboardingRemote
  let subscriptionStore: any SubscriptionStore
  let soundRepository: any SoundContentRepository
  let soundPlayer: any SoundPlaying
  let practiceStore: any PracticeStore
  /// App-lifetime ledger so hearts earned in a session show up in Portfolio.
  /// Still the in-memory sample — nothing persists it yet.
  let heartLedger: HeartLedger

  init() {
    let config = AppConfig.current
    let client = APIClient(baseURL: config.apiBaseURL, tokens: KeychainTokenStore())
    self.config = config
    self.apiClient = client
    self.accountStore = APIAccountStore(client: client)
    self.onboardingStore = OnboardingProgressDefaultsStore()
    self.onboardingRemote = APIOnboardingRemote(client: client)
    self.subscriptionStore = StoreKitSubscriptionStore()
    self.soundRepository = APISoundContentRepository(client: client)
    self.soundPlayer = StreamingSoundPlayer()
    self.practiceStore = PracticeDefaultsStore(remote: APIPracticeRemote(client: client))
    self.heartLedger = .sample
  }
}
