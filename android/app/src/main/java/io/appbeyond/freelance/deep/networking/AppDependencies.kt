package io.appbeyond.freelance.deep.networking

import android.content.Context
import android.media.MediaMetadataRetriever
import androidx.annotation.RawRes
import androidx.core.net.toUri
import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import io.appbeyond.freelance.deep.auth.TokenRefresher
import io.appbeyond.freelance.deep.auth.TokenStoring
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.config.AppConfig
import io.appbeyond.freelance.deep.feature.compassion.store.HeartLedger
import io.appbeyond.freelance.deep.feature.deepsound.model.ListenRules
import io.appbeyond.freelance.deep.feature.deepsound.player.SoundPlayer
import io.appbeyond.freelance.deep.feature.deepsound.player.TrackListenReporting
import io.appbeyond.freelance.deep.feature.deepsound.store.ApiSoundLibrary
import io.appbeyond.freelance.deep.feature.deepsound.store.SoundLibrary
import io.appbeyond.freelance.deep.feature.globalpause.earth.CountryLookup
import io.appbeyond.freelance.deep.feature.globalpause.model.SyncedClock
import io.appbeyond.freelance.deep.feature.globalpause.store.GlobalPauseSession
import io.appbeyond.freelance.deep.feature.globalpause.store.PauseEventRemote
import io.appbeyond.freelance.deep.feature.globalpause.store.PresenceIdStore
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
import io.appbeyond.freelance.deep.feature.rewards.PauseNightRewards
import io.appbeyond.freelance.deep.feature.rewards.PracticeRewards
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.feature.rewards.store.ContinuityWitness
import io.appbeyond.freelance.deep.feature.rewards.store.ListenReporter
import io.appbeyond.freelance.deep.feature.rewards.store.RewardsRemote
import io.appbeyond.freelance.deep.feature.reminders.AlarmReminderScheduler
import io.appbeyond.freelance.deep.feature.reminders.store.ReminderStore
import io.appbeyond.freelance.deep.shared.localization.AppLanguage
import io.appbeyond.freelance.deep.shared.localization.DeviceRegion
import io.appbeyond.freelance.deep.shared.localization.LanguageStore
import io.appbeyond.freelance.deep.shared.persistence.DataStoreBlobStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import java.time.Clock
import java.time.Duration
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
   * Process-lifetime scope for work that must outlive any single screen —
   * [onboardingStore]'s eager DataStore load, the queued listen reports, the
   * rewards sync, gifts of hearts, and the stores' writes.
   * `SupervisorJob` so a failure in one can never cancel another.
   */
  private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

  /**
   * The member's language choice, persisted in `deep.language` and applied
   * through the per-app locale API. Device state rather than account state,
   * so it outlives a log out — the same reason iOS keeps `LanguageStore`
   * outside the account. Read synchronously here, as the process starts, so
   * the first frame is already in the chosen language.
   */
  val languageStore: LanguageStore = LanguageStore(
    context = context.applicationContext,
    blob = DataStoreBlobStore(context.applicationContext, "deep.language"),
    scope = appScope,
  ).also { it.load() }

  /** The language every screen and every server-authored string reads in. */
  val language: AppLanguage get() = languageStore.selection.value

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
   * continuity day ([resetAccountState]); the stores it reaches are built
   * below, and the callback can only run long after construction.
   */
  val accountStore: AccountStore = ApiAccountStore(
    auth = retrofit.create(AuthService::class.java),
    tokens = tokens,
    refresher = tokenRefresher,
    cache = AccountCache(context.applicationContext),
    onInvoluntarySignOut = {
      onboardingProgressStore.reset()
      resetAccountState()
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
  val soundPlayer: SoundPlayer = SoundPlayer(
    context = context.applicationContext,
    // The listener's Repeat choice: the phone's, like the language, so it
    // outlives a log out — iOS keeps it in `UserDefaults`.
    settings = DataStoreBlobStore(context.applicationContext, "deep.sound"),
  )

  private val soundService: SoundService = retrofit.create(SoundService::class.java)

  /**
   * The shelves and the lyrics. `/sound/home` is anonymous-tolerant, like
   * `pauseHome`, but answers each account differently (DEEP Premium locks), so
   * the library keys what it keeps by the signed-in account.
   */
  val soundLibrary: SoundLibrary = ApiSoundLibrary(
    service = soundService,
    currentAccountId = { accountStore.account.value?.id },
  )

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
   * signed-in check sits here as well). A wallet that arrived means the
   * server is reachable again, so a gift whose answer was lost is re-sent
   * under its own id right after ([HeartLedger.reconcile]).
   */
  val gardenStore: GardenStore = GardenStore(
    remote = rewardsRemote,
    blob = DataStoreBlobStore(context.applicationContext, "deep.garden"),
  ).also { garden ->
    garden.heartsChanged = { wallet ->
      if (isSignedIn) {
        heartLedger.hydrate(wallet)
        if (heartLedger.hasUnconfirmedSpends) launchQuietly("hearts reconcile") { heartLedger.reconcile() }
      }
    }
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
   * [resetAccountState] would write the last member's balance and sunlight
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

  private val soundListens: SoundListensService = retrofit.create(SoundListensService::class.java)

  /**
   * Finished tracks, queued durably in `deep.sound.pendingListens` and
   * reported with their finish time, so a dropped connection never costs the
   * heart; the rules themselves live server-side. Each finish keeps its day
   * in [practiceJournal] first, whatever the server says. Rides the one
   * Retrofit, so the report carries the member's timezone and the award lands
   * on their local day; the grant goes to [ingestAwards]. Its notices are what
   * the mini player and Now Playing say.
   */
  val listenReporter: ListenReporter = ListenReporter(
    report = soundListens::reportListen,
    recordActivity = practiceJournal::recordTrackDay,
    queueBlob = DataStoreBlobStore(context.applicationContext, "deep.sound.pendingListens"),
    stampBlob = DataStoreBlobStore(context.applicationContext, "deep.sound.dayCompleteNoticed"),
    scope = appScope,
    clock = clock,
    zone = zone,
  ).also { reporter -> reporter.awardSink = ingestAwards }

  /**
   * Told by the service when a track plays through to its natural end. The
   * finish is stamped now, on the caller's thread, and queued on [appScope] —
   * so a listen recorded as the service winds down still lands on disk.
   */
  val trackListens: TrackListenReporting = TrackListenReporting { trackId ->
    val finishedAt = clock.instant()
    launchQuietly("listen record") { listenReporter.record(trackId, finishedAt) }
  }

  // Week five: giving, the daily reminder, and the language picker (above).

  /**
   * Gives hearts to a cause, on [appScope] so the donate sheet's exit (or a
   * tab switch) can never cut a gift off between its optimistic move and its
   * settle. The ledger books it at once; the POST follows.
   */
  fun giveHearts(amount: Int, causeId: String, projectId: String?) {
    launchQuietly("hearts spend") { heartLedger.send(amount, causeId, projectId) }
  }

  /**
   * The daily reminder, persisted in `deep.reminder` and armed through
   * [AlarmReminderScheduler]. A property of this phone rather than the
   * account, but switched off by every exit ([resetAccountState]): the nudge
   * is about practice, and practice leaves with the account.
   */
  val reminderStore: ReminderStore = ReminderStore(
    scheduler = AlarmReminderScheduler(context.applicationContext),
    blob = DataStoreBlobStore(context.applicationContext, "deep.reminder"),
    clock = clock,
    zone = { ZoneId.systemDefault() },
  )

  /** Whether today already counts as practised — the goal met, or a Global
   * Pause sat ([PracticeJournal.reminderRestsToday]). The one fact the
   * reminder store deliberately doesn't know; every evaluation reads it. */
  private suspend fun practisedToday(): Boolean {
    practiceJournal.restore()
    return practiceJournal.reminderRestsToday()
  }

  /**
   * Rebuilds the reminder against today's practice — iOS's
   * `rescheduleReminder()`, run on every foreground and as the app leaves it
   * (so a practice finished just now quiets today's nudge), and by the boot
   * and clock receivers.
   */
  suspend fun rescheduleReminder() {
    reminderStore.reschedule(practisedToday = practisedToday())
  }

  /** [rescheduleReminder] fire-and-forget, for lifecycle seams. */
  fun rescheduleReminderQuietly() {
    launchQuietly("reminder reschedule") { rescheduleReminder() }
  }

  /** Turns the reminder on — the screen supplies the permission [prompt]. */
  suspend fun enableReminder(prompt: suspend () -> Boolean) =
    reminderStore.enable(practisedToday = practisedToday(), prompt = prompt)

  /** A new clock face for the reminder. */
  suspend fun setReminderTime(hour: Int, minute: Int) =
    reminderStore.setTime(hour, minute, practisedToday = practisedToday())

  /**
   * Adopts a language. The view tree recreates in it (the per-app locale);
   * the server-authored content the process holds is refetched in it, since
   * `Accept-Language` follows the choice from the next request on. The
   * reminder needs nothing: it resolves its words as it fires (iOS
   * reschedules here only because it bakes the words into each request).
   */
  fun selectLanguage(selected: AppLanguage) {
    val changed = selected != language
    languageStore.select(selected)
    if (!changed) return
    syncRewards()
    launchQuietly("playlist reload") { playlistStore.load() }
    launchQuietly("sound shelves reload") { soundLibrary.shelves() }
  }

  // Week six: Global Pause. The engine is app-lifetime, like iOS's — the
  // Home card and the lounge need tonight's schedule long before a session is
  // ever opened — and runs on the main thread, as the `@MainActor` original
  // does, so it never needs a lock. Its clock is synced off every pause
  // response, so dev time travel moves the whole feature at once.

  /** The server's clock, as the pause reads it. */
  val pauseClock: SyncedClock = SyncedClock()

  private val mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

  /** The live event routes (`/pause/…`) and `/me/pause/award`. */
  val pauseEvents: PauseEventRemote =
    ApiPauseEventRemote(retrofit.create(PauseEventService::class.java), pauseClock)

  /** One anonymous presence id per install, in `deep.pause`. */
  private val presenceIds = PresenceIdStore(DataStoreBlobStore(context.applicationContext, "deep.pause"))

  /**
   * The live pause. Its settled awards go through the one [ingestAwards], and
   * a night the server counted keeps the day in the practice journal — unless
   * the member has signed out meanwhile.
   */
  val globalPause: GlobalPauseSession = GlobalPauseSession(
    clock = pauseClock,
    remote = pauseEvents,
    scope = mainScope,
    presenceId = presenceIds::id,
    // The device's region, not the in-app language's: a member reading in
    // Thai on an English-region phone is pausing from where the phone is.
    countryIso = { DeviceRegion.isoCode(context.applicationContext) },
    // The globe's country table: joins the server couldn't place land on their
    // country, and the arrival turn has somewhere to aim before the first
    // heartbeat resolves the member's own point.
    countryCentroid = CountryLookup::centroid,
    introDuration = { bundledDuration(context.applicationContext, R.raw.fuku_intro) },
    awardSink = { grant -> ingestAwards(grant) },
    // An eligible claim keeps the day in the rhythm and rests today's
    // reminder at once (iOS PR #62). Stamped with the device's clock, as iOS
    // stamps `Date.now`: the pause clock follows the server, and a
    // time-travelled server would file the sit under the wrong day.
    activitySink = { _ ->
      if (isSignedIn) {
        practiceJournal.recordPauseDay(clock.instant())
        rescheduleReminderQuietly()
      }
    },
  )

  /** The books a pause night's ending reads. */
  val pauseNightRewards: PauseNightRewards = PauseNightRewards(
    session = globalPause,
    journal = practiceJournal,
    ledger = heartLedger,
    garden = gardenStore,
    witness = continuityWitness,
  )

  private val isSignedIn: Boolean get() = accountStore.account.value != null

  /**
   * Pulls the garden (and the wallet riding it), syncs the practice journal —
   * pushing the offline queue, then merging sessions recorded on other
   * installs — and offers the queued listens, in parallel on [appScope]. A
   * no-op while signed out.
   *
   * iOS runs this from three seams in `AppRootView`: `bootstrap()`, the
   * `.flow → .main` phase change, and every return to `.active`. Here
   * `AppRoot` calls it as the shell is composed (launch and sign-in alike)
   * and on every process foreground after that. All three are single-flight,
   * so an overlapping call is harmless.
   */
  fun syncRewards() {
    if (!isSignedIn) return
    launchQuietly("garden refresh") { gardenStore.refresh() }
    launchQuietly("practice sync") { practiceJournal.refresh() }
    // Listens finished offline, or cut off by a kill, go out here.
    launchQuietly("listen flush") { listenReporter.flush() }
  }

  /**
   * Offers the practice journal's unsynced sessions and the queued listens to
   * the server, side by side, each giving up after [LOG_OUT_FLUSH_TIMEOUT].
   * True when nothing is left behind. Settings' log out runs this *before*
   * ending the session, while the token still works, and asks the member
   * before dropping whatever is left — iOS's `SettingsView.logOut()`. A dead
   * network delays the log out by seconds at most.
   */
  suspend fun flushBeforeLogOut(): Boolean = try {
    coroutineScope {
      val practice = async { practiceJournal.flushPending(LOG_OUT_FLUSH_TIMEOUT) }
      val listens = async { listenReporter.flush(LOG_OUT_FLUSH_TIMEOUT) }
      val practiceSynced = practice.await()
      val listensSynced = listens.await()
      practiceSynced && listensSynced
    }
  } catch (cancelled: CancellationException) {
    throw cancelled
  } catch (unexpected: Exception) {
    // Unknown is not synced: the member is asked rather than losing practice.
    Log.w(TAG, "Flush before log out failed.", unexpected)
    false
  }

  /**
   * Forgets everything the account's stores hold for the signed-out member —
   * journal, queued listens, garden, hearts, the continuity day — on disk and
   * in memory, so the next member never inherits any of it, and switches the
   * daily reminder off and back to its default time (iOS only switches it
   * off). Every exit
   * calls this: Settings' log out and account deletion, the server ending a session
   * ([accountStore]'s involuntary sign-out), `AppRoot`'s rejected launch
   * restore, and the account watcher below. Idempotent, so the overlap is
   * harmless; runs to completion even if its caller is cancelled. A response
   * still in flight for the old member is dropped by each store's generation
   * stamp when it lands.
   */
  suspend fun resetAccountState() {
    withContext(NonCancellable) {
      practiceJournal.reset()
      // Queued listens and today's notices belong to the account: a report
      // still in flight is dropped as it lands, never credited to the next.
      listenReporter.reset()
      gardenStore.resetLocalState()
      heartLedger.resetLocalState()
      continuityWitness.resetLocalState()
      // A pause-night claim still out lands on nobody's books.
      globalPause.forgetAccount()
      // The nudge is about practice, and practice leaves with the account —
      // so the alarm goes too, and its time with it: the next member starts
      // at 21:00, not at the last one's hour. The *language* stays: what you
      // read in belongs to the phone, not to whoever is signed into it.
      reminderStore.reset()
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
    launchQuietly("listen queue restore") { listenReporter.restore() }

    // The reminder window rolls forward on every return to the app, and
    // rebuilds as the app leaves it so a practice finished just now quiets
    // today's nudge — iOS's scene-phase `.active` reschedule, plus the exit.
    // The process lifecycle, not an activity's: a rotation or a language
    // change recreates the activity without the member leaving.
    ProcessLifecycleOwner.get().lifecycle.addObserver(
      object : DefaultLifecycleObserver {
        override fun onStart(owner: LifecycleOwner) {
          rescheduleReminderQuietly()
          // Also the launch: registering replays ON_START. Re-resolves the
          // schedule (and so the clock) and resumes a session's live poll.
          globalPause.onForeground()
        }

        override fun onStop(owner: LifecycleOwner) {
          rescheduleReminderQuietly()
          globalPause.onBackground()
        }
      },
    )

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
            resetAccountState()
          }
          before = after
        }
    }
  }

  private companion object {
    const val TAG = "AppDependencies"

    /** How long a log out waits on each flush before asking the member — iOS's three seconds. */
    val LOG_OUT_FLUSH_TIMEOUT: Duration = Duration.ofSeconds(3)
  }
}

/**
 * How long a bundled clip runs, read off the file — so the lounge's intro
 * hand-off never drifts from the footage the way a typed constant does the
 * first time it's recut. Zero when it can't be read, which the broadcast
 * reads as "no intro".
 */
private suspend fun bundledDuration(context: Context, @RawRes resource: Int): Duration =
  withContext(Dispatchers.IO) {
    val retriever = MediaMetadataRetriever()
    try {
      retriever.setDataSource(context, "android.resource://${context.packageName}/$resource".toUri())
      retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
        ?.let(Duration::ofMillis) ?: Duration.ZERO
    } catch (unreadable: RuntimeException) {
      Log.w("AppDependencies", "Could not read a bundled clip's length", unreadable)
      Duration.ZERO
    } finally {
      retriever.release()
    }
  }
