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
  /// The reward backend shared by every award producer and both stores.
  let rewardsRemote: any RewardsRemote
  /// App-lifetime ledger so hearts earned in a session show up in Portfolio.
  /// Starts empty; the first garden/wallet fetch hydrates it with server truth.
  let heartLedger: HeartLedger
  /// The garden's plant + sunlight, server-backed and persisted for offline.
  let gardenStore: GardenStore
  /// The one day-stamp behind the continuity beat, shared by every ending so
  /// the rhythm is noticed once a day rather than once per feature.
  let continuityWitness: ContinuityWitness
  let pauseClock: SyncedClock
  let pauseRepository: any PauseEventRepository
  let pauseSession: GlobalPauseSession
  let imageLoader: any ImageLoading
  /// Disk cache for the garden's stage hero footage — streamed once, played
  /// from disk on every later launch.
  let videoCache: VideoCache

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

    // Rewards: remote → ledger → garden → the one ingest seam. Every award
    // producer (practice sync, track listens, pause claim, peace messages)
    // hands its settled `AwardGrant` to this closure, which reconciles both
    // stores with the grant's absolute figures.
    let rewards = APIRewardsRemote(client: client)
    let ledger = HeartLedger(remote: rewards)
    let garden = GardenStore(remote: rewards)
    let ingestAwards: @MainActor (AwardGrant) -> Void = { grant in
      ledger.apply(grant)
      garden.apply(grant)
    }
    // Wallet snapshots ride the garden fetch — one refresh hydrates both.
    garden.heartsChanged = { summary in ledger.hydrate(summary) }
    self.rewardsRemote = rewards
    self.heartLedger = ledger
    self.gardenStore = garden
    self.continuityWitness = ContinuityWitness()

    let practiceStore = PracticeDefaultsStore(remote: APIPracticeRemote(client: client))
    practiceStore.awardSink = ingestAwards
    self.practiceStore = practiceStore

    // A track played through to its end reports fire-and-forget: a lost
    // report costs at most one heart, and the rules live server-side.
    self.soundPlayer = StreamingSoundPlayer { track in
      Task { @MainActor in
        guard let grant = try? await rewards.reportListen(trackId: track.id) else { return }
        ingestAwards(grant)
      }
    }

    // Keyed by environment so Dev and Staging artwork can never collide on a
    // shared /media path — see `ImageLoader.cacheKey(for:environmentKey:)`.
    self.imageLoader = ImageLoader(environmentKey: config.environment.rawValue)
    self.videoCache = VideoCache(environmentKey: config.environment.rawValue)

    // Global Pause: one synced clock + one app-long phase engine, so the home
    // feed's countdown and the lobby run off the same time authority.
    let clock = SyncedClock()
    let pauseRepository = APIPauseEventRepository(client: client, clock: clock)
    self.pauseClock = clock
    self.pauseRepository = pauseRepository
    self.pauseSession = GlobalPauseSession(
      clock: clock,
      repository: pauseRepository,
      rewards: rewards,
      awardSink: ingestAwards
    )
  }
}
