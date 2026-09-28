package io.appbeyond.freelance.deep.networking

import android.content.Context
import io.appbeyond.freelance.deep.auth.TokenRefresher
import io.appbeyond.freelance.deep.auth.TokenStoring
import io.appbeyond.freelance.deep.config.AppConfig
import io.appbeyond.freelance.deep.feature.deepsound.model.ListenRules
import io.appbeyond.freelance.deep.feature.deepsound.player.ApiTrackListenReporter
import io.appbeyond.freelance.deep.feature.deepsound.player.SoundPlayer
import io.appbeyond.freelance.deep.feature.deepsound.player.TrackListenReporting
import io.appbeyond.freelance.deep.feature.deepsound.store.ApiSoundLibrary
import io.appbeyond.freelance.deep.feature.deepsound.store.SoundLibrary
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
import io.appbeyond.freelance.deep.shared.localization.AppLanguage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory

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
   * [onboardingStore]'s eager DataStore load, and the fire-and-forget listen
   * reports. `SupervisorJob` so a failure in one can never cancel another.
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
   * them on a voluntary log out, so whoever signs in next starts clean.
   */
  val accountStore: AccountStore = ApiAccountStore(
    auth = retrofit.create(AuthService::class.java),
    tokens = tokens,
    refresher = tokenRefresher,
    cache = AccountCache(context.applicationContext),
    onInvoluntarySignOut = { onboardingProgressStore.reset() },
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

  // Week three: Deep Sound. The player is process-lifetime, like iOS's
  // `soundPlayer`, so the mini player and the lock screen outlive every screen
  // that started a track. The audio itself plays in `DeepSoundService`, which
  // reads `http`, `trackListens` and `accountStore` from here when the system
  // starts it — it runs in this process, so it shares this graph rather than
  // building a second one.

  /**
   * Told by the service when a track plays through to its natural end. Rides
   * the one Retrofit, so the report carries the member's timezone and the award
   * lands on their local day, as iOS's `reportListen` does.
   */
  val trackListens: TrackListenReporting = ApiTrackListenReporter(
    service = retrofit.create(SoundListensService::class.java),
    scope = appScope,
  )

  /**
   * The one player. Connects to the service lazily, on the first track, so a
   * member who never opens Deep Sound never starts it.
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

  init {
    // A member signing out takes their queue and their saved sounds with them:
    // the next person on this phone must not find the last one's track in the
    // mini player, on the lock screen, or in the You tab. Watched here, not in Settings, because a session can also
    // end server-side (a refused refresh) with no screen involved.
    // `ListenRules.shouldClearPlayer` decides which changes count — never a
    // first sign-in, always a sign-out or a switch.
    appScope.launch(Dispatchers.Main) {
      var before: String? = null
      accountStore.account
        .map { it?.id }
        .distinctUntilChanged()
        .collect { after ->
          if (ListenRules.shouldClearPlayer(before, after)) {
            soundPlayer.clear()
            playlistStore.resetLocalState()
          }
          before = after
        }
    }
  }
}
