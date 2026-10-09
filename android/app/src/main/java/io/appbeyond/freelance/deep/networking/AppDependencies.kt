package io.appbeyond.freelance.deep.networking

import android.content.Context
import android.util.Log
import io.appbeyond.freelance.deep.auth.TokenRefresher
import io.appbeyond.freelance.deep.auth.TokenStoring
import io.appbeyond.freelance.deep.config.AppConfig
import io.appbeyond.freelance.deep.feature.compassion.store.HeartLedger
import io.appbeyond.freelance.deep.feature.deepsound.model.ListenRules
import io.appbeyond.freelance.deep.feature.deepsound.player.ApiTrackListenReporter
import io.appbeyond.freelance.deep.feature.deepsound.player.SoundPlayer
import io.appbeyond.freelance.deep.feature.deepsound.player.TrackListenReporting
import io.appbeyond.freelance.deep.feature.deepsound.store.ApiSoundLibrary
import io.appbeyond.freelance.deep.feature.deepsound.store.SoundLibrary
import io.appbeyond.freelance.deep.feature.mindgarden.store.GardenStore
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountCache
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.ApiAccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.ApiOnboardingRemote
import io.appbeyond.freelance.deep.feature.onboarding.store.DataStoreOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingRemote
import io.appbeyond.freelance.deep.feature.playlist.store.ApiPlaylistStore
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistCache
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistStore
import io.appbeyond.freelance.deep.feature.practice.store.PracticeJournal
import io.appbeyond.freelance.deep.feature.rewards.PracticeRewards
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.feature.rewards.store.ContinuityWitness
import io.appbeyond.freelance.deep.feature.rewards.store.RewardsRemote
import io.appbeyond.freelance.deep.shared.localization.AppLanguage
import io.appbeyond.freelance.deep.shared.persistence.DataStoreBlobStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import java.time.Clock
import java.time.ZoneId

/**
 * The composition root. One instance, built in [io.appbeyond.freelance.deep.DeepApplication].
 *
 * Wired by hand rather than by an injection framework, mirroring
 * `Deep/Deep/Networking/AppDependencies.swift`. That file does not describe a
 * dependency graph so much as an ordered, mutually-referential wiring: it builds
 * the rewards remote, then the ledger and the garden over it, then closes an
 * `ingestAwards` lambda over both, then hands that lambda to the practice store,
 * the sound player and the pause session. Expressed in Hilt it would collapse
 * into one `@Provides` that does the same wiring anyway, for the price of an
 * annotation processor in the build and friction in every `@Preview`.
 *
 * Read it top to bottom: config, the session store, the client over it, the one
 * Retrofit built on that client, then the repositories. Stores arrive here as the
 * weeks land.
 */
class AppDependencies(context: Context) {

  val config: AppConfig = AppConfig

  /**
   * The language every screen and every server-authored string reads in.
   *
   * Device state rather than account state, so it outlives a log out — the same
   * reason iOS keeps `LanguageStore` outside the account. Seeded from the
   * device and held in memory for now; a persisted picker replaces this line
   * without touching anything that reads it.
   */
  @Volatile
  var language: AppLanguage = AppLanguage.deviceMatched()

  /** The token pair, encrypted at rest. The only secret this app keeps. */
  val tokens: TokenStoring = KeystoreTokenStore(context.applicationContext)

  /** The app's single HTTP seam: headers, bearer token, and the 401 retry. */
  val http: DeepHttp = DeepHttp(
    baseUrl = config.apiBaseUrl,
    tokens = tokens,
    json = DeepJson,
    language = { language },
    logRequests = config.isDev,
  )

  /**
   * The single-flight path the authenticator rotates through, and the one
   * writer of [tokens]: [accountStore] starts and ends sessions through it so a
   * late rotation of an old session can never clobber a new one.
   */
  val tokenRefresher: TokenRefresher = http.tokenRefresher

  /**
   * The one Retrofit, on the one client.
   *
   * The trailing slash is added here and nowhere else: Retrofit requires the
   * base URL to end in one, and `AppConfig.apiBaseUrl` deliberately does not, so
   * that hand-built calls (`AuthRefreshEndpoint`) can append a leading-slash
   * path the way `APIClient` does on iOS.
   */
  private val retrofit: Retrofit = Retrofit.Builder()
    .baseUrl(config.apiBaseUrl + "/")
    .client(http.client)
    .addConverterFactory(DeepJson.asConverterFactory(DeepJsonMediaType))
    .build()

  val pauseHome: PauseHomeRepository =
    PauseHomeRepository(retrofit.create(PauseHomeService::class.java))

  /**
   * Process-lifetime scope for work that must outlive any single screen —
   * [onboardingStore]'s eager DataStore load, the fire-and-forget listen
   * reports, and the rewards sync. `SupervisorJob` so a failure in one can
   * never cancel another.
   */
  private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

  // Week two: accounts and onboarding. Both `accountStore` and
  // `onboardingRemote` ride the same Retrofit and the same token store as
  // `pauseHome` above — signing in rotates the pair `http`'s authenticator
  // already knows how to refresh, with no wiring of its own. The onboarding
  // *progress* store needs no network at all: it is local DataStore state
  // that a returning member's `onboardingRemote.fetchProfile()` overwrites
  // wholesale after login.
  private val onboardingProgressStore =
    DataStoreOnboardingProgressStore(context.applicationContext, appScope)
  val onboardingStore: OnboardingProgressStore = onboardingProgressStore

  /**
   * Built after [onboardingStore] because it holds on to it: when the server
   * ends a signed-in session — a refused refresh, a rejected restore — the
   * previous member's onboarding answers are reset exactly as Settings resets
   * them on a voluntary log out, so whoever signs in next starts clean. Since
   * week four the same exit also forgets their garden, hearts, journal and
   * continuity day ([resetRewardsState]); the stores it reaches are built
   * below, and the callback can only run long after construction.
   */
  val accountStore: AccountStore = ApiAccountStore(
    auth = retrofit.create(AuthService::class.java),
    tokens = tokens,
    refresher = tokenRefresher,
    cache = AccountCache(context.applicationContext),
    onInvoluntarySignOut = {
      onboardingProgressStore.reset()
      resetRewardsState()
    },
  )

  val onboardingRemote: OnboardingRemote =
    ApiOnboardingRemote(retrofit.create(OnboardingService::class.java))

  /**
   * Suspends until [onboardingStore]'s first real load — from disk, or
   * [io.appbeyond.freelance.deep.onboarding.model.OnboardingState.Fresh] on a
   * clean install — has landed in its `state`. The root view awaits this
   * alongside [accountStore]'s [AccountStore.restore] before computing the
   * root phase, so a persisted "onboarding complete" is never missed for one
   * frame. See `DataStoreOnboardingProgressStore.awaitLoaded`.
   */
  suspend fun awaitOnboardingLoaded() = onboardingProgressStore.awaitLoaded()

  // Week three: DEEP Sound. The player is process-lifetime, like iOS's
  // `soundPlayer`, so the mini player and the lock screen outlive every screen
  // that started a track. The audio itself plays in `DeepSoundService`, which
  // reads `http`, `trackListens` and `accountStore` from here when the system
  // starts it — it runs in this process, so it shares this graph rather than
  // building a second one. (`trackListens` moved down to week four, once its
  // reply started feeding the award ingest built there.)

  /**
   * The one player. Connects to the service lazily, on the first track, so a
   * member who never opens DEEP Sound never starts it.
   */
  val soundPlayer: SoundPlayer = SoundPlayer(context.applicationContext)

  private val soundService: SoundService = retrofit.create(SoundService::class.java)

  /** The shelves and the lyrics. `/sound/home` is anonymous-tolerant, like `pauseHome`. */
  val soundLibrary: SoundLibrary = ApiSoundLibrary(soundService)

  /**
   * The member's saved sounds, cached on disk so the You tab opens on them
   * offline. Hydrates from that cache on [appScope] as it is built.
   */
  val playlistStore: PlaylistStore = ApiPlaylistStore(
    service = soundService,
    cache = PlaylistCache(context.applicationContext),
    scope = appScope,
  )

  // Week four: the Mind Garden, hearts, the practice journal and the reward
  // ritual. The order is iOS's: the rewards remote, then the heart ledger and
  // the garden over it, then `ingestAwards` closed over both, then every
  // producer of awards handed that one lambda — the practice journal's sync
  // and the listen report. The garden fetch carries the wallet, so the garden
  // hydrates the ledger and one pull settles both.
  //
  // Day boundaries (today's hearts, the streak, the once-a-day continuity
  // beat) are read in the device's zone as it was when the process started:
  // the core stores take a fixed `ZoneId`, so a member who flies across a
  // border sees the new day line from the next launch — the server, which
  // reads `X-Device-Timezone` per request, is already right in between.
  //
  // Each persisting store gets its own DataStore file and restores from it
  // eagerly on `appScope`, so an offline cold launch draws the last known
  // garden and journal before the first pull lands.

  private val clock: Clock = Clock.systemDefaultZone()
  private val zone: ZoneId = ZoneId.systemDefault()

  val rewardsRemote: RewardsRemote = ApiRewardsRemote(retrofit.create(RewardsService::class.java))

  /** The member's hearts. Persists nothing — the first garden pull hydrates it. */
  val heartLedger: HeartLedger = HeartLedger(remote = rewardsRemote, clock = clock, zone = zone)

  /**
   * The selected plant and its sunlight, persisted in `deep.garden`. Every
   * wallet riding a garden response hydrates [heartLedger] — unless the
   * member has signed out in the meantime (see [ingestAwards] for why the
   * signed-in check sits here as well).
   */
  val gardenStore: GardenStore = GardenStore(
    remote = rewardsRemote,
    blob = DataStoreBlobStore(context.applicationContext, "deep.garden"),
  ).also { garden ->
    garden.heartsChanged = { wallet -> if (isSignedIn) heartLedger.hydrate(wallet) }
  }

  /** The day the continuity beat was last shown, persisted in `deep.continuity`. */
  val continuityWitness: ContinuityWitness = ContinuityWitness(
    blob = DataStoreBlobStore(context.applicationContext, "deep.continuity"),
    clock = clock,
    zone = zone,
  )

  /**
   * The one award ingest every producer hands its settled grant to: the
   * ledger and the garden each SET the server's absolutes, so the optimistic
   * credits a completion played are reconciled rather than double-counted.
   *
   * A grant that lands after its member signed out is dropped. The core
   * stores already drop late responses by generation, but a grant arrives
   * through *another* store's generation (the journal's) or none at all (a
   * listen report), so without this check a reply settling just after
   * [resetRewardsState] would write the last member's balance and sunlight
   * onto a signed-out device.
   */
  val ingestAwards: suspend (AwardGrant) -> Unit = { grant ->
    if (isSignedIn) {
      heartLedger.apply(grant)
      gardenStore.apply(grant)
    }
  }

  /**
   * Every finished practice, persisted in `deep.practice`. Local-first: a
   * session is recorded the instant it ends and offered to the server by
   * [practiceRewards], [syncRewards] and Settings' log out; the awards each
   * push settles flow into [ingestAwards].
   */
  val practiceJournal: PracticeJournal = PracticeJournal(
    remote = ApiPracticeRemote(retrofit.create(PracticeService::class.java)),
    blob = DataStoreBlobStore(context.applicationContext, "deep.practice"),
    clock = clock,
    zone = zone,
  ).also { journal -> journal.awardSink = ingestAwards }

  /** Turns a finished DEEP Session into the receipt its ending ritual plays. */
  val practiceRewards: PracticeRewards = PracticeRewards(
    journal = practiceJournal,
    ledger = heartLedger,
    garden = gardenStore,
    witness = continuityWitness,
    scope = appScope,
  )

  /**
   * Told by the service when a track plays through to its natural end. Rides
   * the one Retrofit, so the report carries the member's timezone and the award
   * lands on their local day, as iOS's `reportListen` does; the award it earns
   * is folded and handed to [ingestAwards].
   */
  val trackListens: TrackListenReporting = ApiTrackListenReporter(
    service = retrofit.create(SoundListensService::class.java),
    scope = appScope,
    currentAccountId = { accountStore.account.value?.id },
    ingestAwards = ingestAwards,
  )

  private val isSignedIn: Boolean get() = accountStore.account.value != null

  /**
   * Pulls the garden (and the wallet riding it) and syncs the practice
   * journal — pushing the offline queue, then merging sessions recorded on
   * other installs — in parallel on [appScope]. A no-op while signed out.
   *
   * iOS runs this from three seams in `AppRootView`: `bootstrap()`, the
   * `.flow → .main` phase change, and every return to `.active`. Here
   * `AppRoot` calls it as the shell is composed (launch and sign-in alike)
   * and on every process foreground after that. Both stores are
   * single-flight, so an overlapping call is harmless.
   */
  fun syncRewards() {
    if (!isSignedIn) return
    launchQuietly("garden refresh") { gardenStore.refresh() }
    launchQuietly("practice sync") { practiceJournal.refresh() }
  }

  /**
   * Offers the practice journal's unsynced sessions to the server, giving up
   * after three seconds. Settings' log out runs this *before* ending the
   * session, while the token still works.
   *
   * DIVERGENCE: iOS's log out drops unsynced sessions — the journal is reset
   * and whatever never reached the server is gone. A short best-effort push
   * first keeps an offline-then-reconnected member's practice (and the hearts
   * it earns) without ever holding a log out hostage to a dead network.
   */
  suspend fun flushPracticeJournal() {
    try {
      withTimeoutOrNull(PRACTICE_FLUSH_TIMEOUT_MILLIS) { practiceJournal.push() }
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (unexpected: Exception) {
      Log.w(TAG, "Practice flush before log out failed; signing out anyway.", unexpected)
    }
  }

  /**
   * Forgets everything the rewards stores hold for the signed-out member —
   * journal, garden, hearts, the continuity day — on disk and in memory, so
   * the next member never inherits any of it. Every exit calls this: Settings'
   * log out and account deletion, the server ending a session
   * ([accountStore]'s involuntary sign-out), `AppRoot`'s rejected launch
   * restore, and the account watcher below. Idempotent, so the overlap is
   * harmless; runs to completion even if its caller is cancelled. A response
   * still in flight for the old member is dropped by each store's generation
   * stamp when it lands.
   */
  suspend fun resetRewardsState() {
    withContext(NonCancellable) {
      practiceJournal.reset()
      gardenStore.resetLocalState()
      heartLedger.resetLocalState()
      continuityWitness.resetLocalState()
    }
  }

  /** Launches [block] on [appScope], logging rather than crashing on a failure. */
  private fun launchQuietly(what: String, block: suspend () -> Unit) {
    appScope.launch {
      try {
        block()
      } catch (cancelled: CancellationException) {
        throw cancelled
      } catch (unexpected: Exception) {
        Log.w(TAG, "$what failed", unexpected)
      }
    }
  }

  init {
    // Warm the persisted rewards stores now, so the garden and the journal are
    // on screen from disk before anyone asks. Each store restores on first use
    // anyway; this only moves the read off the first screen's critical path.
    launchQuietly("garden restore") { gardenStore.restore() }
    launchQuietly("practice restore") { practiceJournal.restore() }
    launchQuietly("continuity restore") { continuityWitness.restore() }

    // A member signing out takes their queue, their saved sounds and their
    // rewards state with them: the next person on this phone must not find
    // the last one's track in the mini player, on the lock screen, or in the
    // You tab, nor their garden, hearts or journal. Watched here, not in
    // Settings, because a session can also end server-side (a refused
    // refresh) with no screen involved. `ListenRules.shouldClearPlayer`
    // decides which changes count — never a first sign-in, always a sign-out
    // or a switch.
    appScope.launch(Dispatchers.Main) {
      var before: String? = null
      accountStore.account
        .map { it?.id }
        .distinctUntilChanged()
        .collect { after ->
          if (ListenRules.shouldClearPlayer(before, after)) {
            soundPlayer.clear()
            playlistStore.resetLocalState()
            resetRewardsState()
          }
          before = after
        }
    }
  }

  private companion object {
    const val TAG = "AppDependencies"

    /** How long a log out waits on the practice flush before giving up on it. */
    const val PRACTICE_FLUSH_TIMEOUT_MILLIS = 3_000L
  }
}
