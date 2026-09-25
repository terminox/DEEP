package io.appbeyond.freelance.deep.networking

import android.content.Context
import io.appbeyond.freelance.deep.auth.TokenRefresher
import io.appbeyond.freelance.deep.auth.TokenStoring
import io.appbeyond.freelance.deep.config.AppConfig
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountCache
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.ApiAccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.ApiOnboardingRemote
import io.appbeyond.freelance.deep.feature.onboarding.store.DataStoreOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingRemote
import io.appbeyond.freelance.deep.shared.localization.AppLanguage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
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
   * right now, only [onboardingStore]'s eager DataStore load. `SupervisorJob`
   * so a failure loading one store's persisted state can never cancel
   * another's.
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
}
