import SwiftUI

/// The app's composition root. Builds the single `APIClient` (base URL from the
/// active `AppConfig`) and the concrete stores/repositories that hang off it,
/// so everything shares one token store and one network seam. `AppRootView`
/// owns one instance and injects its pieces into the environment.
@MainActor
final class AppDependencies {
  let config: AppConfig
  let apiClient: APIClient

  /// The language every screen and every scheduled notification reads in.
  /// Device state rather than account state, so it outlives a log out.
  let languageStore: LanguageStore
  /// The daily nudge's settings and the system queue behind it. Local to this
  /// phone — nothing about it reaches the server.
  let reminderStore: ReminderStore

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
  /// The sounds this listener saved, server-backed and persisted for offline.
  let playlistStore: PlaylistStore
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
    self.languageStore = LanguageStore()
    self.reminderStore = ReminderStore()
    let accountStore = APIAccountStore(client: client)
    self.accountStore = accountStore
    self.onboardingStore = OnboardingProgressDefaultsStore()
    self.onboardingRemote = APIOnboardingRemote(client: client)
    #if DEBUG
    // This launch argument swaps in the in-memory store so the whole purchase
    // mechanic — plans, selection, the welcome beat, the flipped plan chip — is
    // drivable without RevenueCat or a network. It compiles out of every
    // shipping build.
    if ProcessInfo.processInfo.arguments.contains("-DeepMockSubscriptions") {
      self.subscriptionStore = MockSubscriptionStore.free
    } else {
      self.subscriptionStore = Self.liveSubscriptionStore(config: config, accountStore: accountStore)
    }
    #else
    self.subscriptionStore = Self.liveSubscriptionStore(config: config, accountStore: accountStore)
    #endif
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
    self.playlistStore = PlaylistStore(remote: APIPlaylistRemote(client: client))

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

  /// RevenueCat, speaking for the DEEP user id from the first moment: it starts
  /// as the last signed-in member, and follows every sign-in and sign-out after.
  private static func liveSubscriptionStore(
    config: AppConfig,
    accountStore: APIAccountStore
  ) -> RevenueCatSubscriptionStore {
    let store = RevenueCatSubscriptionStore(
      apiKey: config.revenueCatAPIKey,
      appUserID: accountStore.lastKnownUserID
    )
    accountStore.identitySink = { userID in
      Task { await store.identify(userID: userID) }
    }
    return store
  }
}
