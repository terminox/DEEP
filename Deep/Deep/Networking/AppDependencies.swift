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
  /// The durable queue between finished tracks and the hearts they earn.
  let listenReporter: any ListenReporting
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
  /// The same disk cache decoded at screen size, for the one photograph that
  /// fills the whole screen (Now Playing). Kept apart so a full-size decode
  /// never lands in the shared tile cache's memory.
  let fullScreenImageLoader: any ImageLoading
  /// Disk cache for the garden's stage hero footage — streamed once, played
  /// from disk on every later launch.
  let videoCache: VideoCache

  init() {
    let config = AppConfig.current
    let client = APIClient(baseURL: config.apiBaseURL, tokens: KeychainTokenStore())
    self.config = config
    self.apiClient = client
    self.languageStore = LanguageStore()
    let reminderStore = ReminderStore()
    self.reminderStore = reminderStore
    let accountStore = APIAccountStore(client: client)
    self.accountStore = accountStore
    self.onboardingStore = OnboardingProgressDefaultsStore()
    self.onboardingRemote = APIOnboardingRemote(client: client)
    #if DEBUG
    // A simulator launched with `xcrun simctl` never gets the scheme's
    // `Deep.storekit` configuration, so StoreKit answers with no products at
    // all and the paywall can only ever show its offline state. This launch
    // argument swaps in the in-memory store so the whole purchase mechanic —
    // plans, selection, the welcome beat, the flipped plan chip — is drivable
    // headlessly. It compiles out of every shipping build.
    if ProcessInfo.processInfo.arguments.contains("-DeepMockSubscriptions") {
      self.subscriptionStore = MockSubscriptionStore.free
    } else {
      self.subscriptionStore = StoreKitSubscriptionStore()
    }
    #else
    self.subscriptionStore = StoreKitSubscriptionStore()
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

    // Keyed by environment so Dev and Staging artwork can never collide on a
    // shared /media path — see `ImageLoader.cacheKey(for:environmentKey:)`.
    let imageLoader = ImageLoader(environmentKey: config.environment.rawValue)
    self.imageLoader = imageLoader
    // A full-bleed photo on a 3x phone is ~1200×2600 px; the tile cap of 1280
    // would stretch it soft. Same directory, so bytes on disk are shared.
    self.fullScreenImageLoader = ImageLoader(
      environmentKey: config.environment.rawValue,
      maxPixelSize: 2800
    )

    // A track played through to its end is queued durably and reported with
    // its finish time, so a dropped connection never costs the heart; the
    // rules themselves live server-side.
    let listenReporter = ListenReporter(
      report: { trackId, completedAt in
        try await rewards.reportListen(trackId: trackId, completedAt: completedAt)
      },
      practiceStore: practiceStore
    )
    listenReporter.awardSink = ingestAwards
    self.listenReporter = listenReporter
    // The lock screen's artwork comes through the same image cache the app
    // draws.
    self.soundPlayer = StreamingSoundPlayer(
      loadArtwork: { url in try? await imageLoader.image(for: url) }
    ) { track, finishedAt in
      listenReporter.record(trackId: track.id, finishedAt: finishedAt)
    }
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
      awardSink: ingestAwards,
      // A pause the server counted keeps the day in the member's rhythm, and
      // counts as today's practice for the reminder: the queue is rebuilt
      // now, so tonight's nudge is withdrawn before it can fire rather than
      // at the next foreground.
      activitySink: { date in
        practiceStore.recordActivity(.pause, at: date)
        Task { await reminderStore.reschedule(practisedToday: practiceStore.reminderRestsToday) }
      }
    )

    // A session the server ended (rejected at launch, or its refresh refused)
    // is a log out the member didn't ask for: everything the device held for
    // the account leaves with it, mirroring `SettingsView.completeLogOut()`,
    // so queued listens and unsynced practice can never be credited to the
    // next account that signs in here. An outage never reaches this.
    let onboardingStore = self.onboardingStore
    let continuityWitness = self.continuityWitness
    let playlistStore = self.playlistStore
    accountStore.onSessionEnded = {
      onboardingStore.reset()
      practiceStore.reset()
      listenReporter.reset()
      garden.resetLocalState()
      ledger.resetLocalState()
      continuityWitness.resetLocalState()
      playlistStore.resetLocalState()
      Task { await reminderStore.disable() }
    }
  }
}
