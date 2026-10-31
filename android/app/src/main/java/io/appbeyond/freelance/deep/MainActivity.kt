package io.appbeyond.freelance.deep

import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.lifecycleScope
import io.appbeyond.freelance.deep.feature.appshell.AppRoot
import io.appbeyond.freelance.deep.feature.appshell.PreferenceActions
import io.appbeyond.freelance.deep.feature.compassion.CompassionCategoryScreen
import io.appbeyond.freelance.deep.feature.compassion.CompassionCoordinator
import io.appbeyond.freelance.deep.feature.compassion.rememberCompassionContent
import io.appbeyond.freelance.deep.feature.deepsession.ChimePlayer
import io.appbeyond.freelance.deep.feature.deepsession.DeepSessionCoordinator
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsound.player.playFrom
import io.appbeyond.freelance.deep.feature.globalpause.GlobalPauseHomeScreen
import io.appbeyond.freelance.deep.feature.globalpause.GlobalPauseLobbyScreen
import io.appbeyond.freelance.deep.feature.globalpause.GlobalPauseSessionCoordinator
import io.appbeyond.freelance.deep.feature.globalpause.audio.GlobalPauseAudioPlayer
import io.appbeyond.freelance.deep.feature.globalpause.audio.LoungeRadioPlayer
import io.appbeyond.freelance.deep.feature.globalpause.EarthCardLift
import io.appbeyond.freelance.deep.feature.globalpause.LocalGlobalPauseCardLift
import io.appbeyond.freelance.deep.feature.globalpause.globe.EarthGlobeRendering
import io.appbeyond.freelance.deep.feature.globalpause.globe.GlobeFlight
import io.appbeyond.freelance.deep.feature.globalpause.globe.GlobeScene
import io.appbeyond.freelance.deep.feature.globalpause.globe.LocalGlobeRendering
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.feature.mindgarden.MindGardenHomeScreen
import io.appbeyond.freelance.deep.feature.onboarding.OnboardingCoordinator
import io.appbeyond.freelance.deep.feature.premium.LocalPremiumAccess
import io.appbeyond.freelance.deep.feature.premium.LocalSubscriptionStore
import io.appbeyond.freelance.deep.feature.premium.model.PaywallSource
import io.appbeyond.freelance.deep.feature.premium.model.PremiumGate
import io.appbeyond.freelance.deep.networking.LocalVideoCache
import io.appbeyond.freelance.deep.networking.VideoCache
import io.appbeyond.freelance.deep.theme.exhale
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch

/**
 * The single activity. Everything above this is Compose.
 *
 * Portrait-only and light-only, matching iOS — there is no dark palette to fall
 * back to, so a dark window would show through the atmosphere.
 *
 * Dependencies are read from the application's one composition root rather than
 * resolved from a graph, which is what keeps every screen previewable: each takes
 * what it needs as a parameter and a preview hands it a stub.
 */
class MainActivity : ComponentActivity() {

  /**
   * Below API 33 the per-app locale doesn't exist, so the activity reads in the
   * chosen language by wrapping its own base context (`LanguageStore`); from 33
   * the system has already applied it.
   */
  override fun attachBaseContext(newBase: Context) {
    val dependencies = (newBase.applicationContext as? DeepApplication)?.dependencies
    val localized = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU && dependencies != null) {
      dependencies.languageStore.localized(newBase)
    } else {
      newBase
    }
    super.attachBaseContext(localized)
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    // The splash is moonCream with the DEEP mark; the first frame is moonCream
    // under the atmosphere. The splash fades off it, the exhale, rather than
    // cutting, so the sky arrives instead of jumping in. Opacity only, which
    // reduced motion keeps.
    //
    // Only on a real launch. A recreate (below API 33, the in-app language
    // switch) would otherwise have the compat splash draw its view again — the
    // mark over moonCream for half a second, then the fade — while the launch
    // beat behind it rightly doesn't replay. There the post-splash theme goes
    // on directly and no splash view is drawn; from 31 the system shows no
    // splash for a recreate either.
    if (savedInstanceState == null) {
      installSplashScreen().setOnExitAnimationListener { splash ->
        splash.view.animate().alpha(0f).exhale().withEndAction { splash.remove() }
      }
    } else {
      setTheme(R.style.Theme_Deep)
    }
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)

    val dependencies = (application as DeepApplication).dependencies

    // Debug builds only: `--ez deep.mockSubscriptions true` on the launch
    // intent swaps RevenueCat for the in-memory store, so the purchase
    // mechanic is drivable on an emulator — iOS's `-DeepMockSubscriptions`.
    // `--es deep.mockSubscriptions.variant <name>` picks which fixture (and
    // implies the first), so every paywall state can be staged.
    // `BuildConfig.DEBUG` is a compile-time false in release, so this branch,
    // its keys and the mock all fall out of a shipping build.
    if (BuildConfig.DEBUG) {
      val variant = intent.getStringExtra(MOCK_SUBSCRIPTIONS_VARIANT_EXTRA)
      if (variant != null || intent.getBooleanExtra(MOCK_SUBSCRIPTIONS_EXTRA, false)) {
        dependencies.useMockSubscriptions(variant)
      }
    }
    // Built here, after that decision, and before the launch beat restores the
    // session — so the member's remembered DEEP Premium answer is read in time.
    dependencies.startPremium()

    // From 33 a language picked in the system's per-app settings reaches a
    // running process as a configuration change ([onConfigurationChanged]);
    // one picked while DEEP was not running is adopted here. Either way the
    // reminder and server copy follow the language the screens read in.
    dependencies.languageStore.adoptSystemChoice()

    // Below API 33 a new language means a new base context: recreate, as the
    // system does itself from 33 when the per-app locale changes.
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
      val chosen = dependencies.languageStore.selection.value
      lifecycleScope.launch {
        dependencies.languageStore.selection
          .drop(1)
          .collect { if (it != chosen) recreate() }
      }
    }

    val preferences = PreferenceActions(
      selectLanguage = dependencies::selectLanguage,
      enableReminder = dependencies::enableReminder,
      setReminderTime = dependencies::setReminderTime,
      disableReminder = { dependencies.reminderStore.disable() },
    )
    // Remote stage footage fills this as it plays, so the Garden's hero loops
    // from disk on every visit after the first — iOS's `VideoCache`.
    val videoCache = VideoCache.shared(this, dependencies.http.mediaClient)

    setContent {
      val language by dependencies.languageStore.selection.collectAsStateWithLifecycle()
      // One globe for the whole app, so the lounge card and the live session
      // draw the same one — what the card lift moves between them.
      val globeScene = remember { GlobeScene() }
      // The Earth and the lift share one flight: the lift drives it, the
      // session's globe rides it. Reduced motion keeps the crossfade.
      val globeFlight = remember { GlobeFlight() }
      val globeRendering = remember { EarthGlobeRendering(globeFlight) }
      val reduceMotion = rememberReduceMotion()
      val cardLift = remember(reduceMotion) { EarthCardLift(globeFlight, reduceMotion) }
      val pause by dependencies.globalPause.state.collectAsStateWithLifecycle()
      // The DEEP Session's closing bell, owned out here rather than by the
      // practice: it rings for close to four seconds, long enough to tap
      // through the reward ritual and close while it still sounds, and a bell
      // owned by the cover would be cut off mid-ring as the cover leaves —
      // iOS's `DeepSessionRunModifier` owns it outside the presentation too.
      val chime = remember { ChimePlayer(applicationContext) }
      DisposableEffect(chime) { onDispose { chime.release() } }
      // Fuku's radio, owned out here rather than by the lounge so the Global
      // Pause can silence it on its way in: the lounge stays composed under
      // the session's cover, so its own teardown never runs then — iOS's
      // coordinator owns it for the same reason.
      val loungeRadio = remember { LoungeRadioPlayer(applicationContext, dependencies.http.mediaClient) }
      DisposableEffect(loungeRadio) { onDispose { loungeRadio.release() } }
      CompositionLocalProvider(
        LocalVideoCache provides videoCache,
        LocalGlobeRendering provides globeRendering,
        LocalGlobalPauseCardLift provides cardLift,
        // Every lock reads this one answer, however deep it is drawn.
        LocalPremiumAccess provides dependencies.premiumAccess,
        LocalSubscriptionStore provides dependencies.subscriptionStore,
      ) {
        AppRoot(
          accountStore = dependencies.accountStore,
          onboardingStore = dependencies.onboardingStore,
          onboardingRemote = dependencies.onboardingRemote,
          awaitOnboardingLoaded = dependencies::awaitOnboardingLoaded,
          language = language,
          reminderStore = dependencies.reminderStore,
          preferences = preferences,
          soundPlayer = dependencies.soundPlayer,
          listenReporter = dependencies.listenReporter,
          soundLibrary = dependencies.soundLibrary,
          playlistStore = dependencies.playlistStore,
          syncRewards = dependencies::syncRewards,
          flushBeforeLogOut = dependencies::flushBeforeLogOut,
          resetAccountState = dependencies::resetAccountState,
          refreshPremiumIfUnanswered = dependencies::refreshPremiumIfUnanswered,
          refreshPremium = dependencies::refreshPremium,
          flowContent = {
            OnboardingCoordinator(
              accountStore = dependencies.accountStore,
              onboardingStore = dependencies.onboardingStore,
              remote = dependencies.onboardingRemote,
            )
          },
          homeContent = { actions ->
            // Keyed on the member, so the personalised "Made for you" shelf
            // reloads for whoever just signed up or logged in rather than
            // keeping the feed fetched before their token existed.
            val account by dependencies.accountStore.account.collectAsStateWithLifecycle()
            GlobalPauseHomeScreen(
              repository = dependencies.pauseHome,
              onOpenDeepSession = actions.openDeepSession,
              // A tile's or card's body pushes the collection's detail; only its
              // small round play button starts it in place — iOS's `HomeTile` /
              // `FeatureCard`.
              onOpenCollection = actions.openCollection,
              // Through the gate, like a collection's own Play: only what this
              // listener may hear is queued, and nothing to hear opens the
              // DEEP Premium invitation on Home's stack instead.
              onPlayCollection = { collection ->
                val queue = PremiumGate.playable(collection, dependencies.premiumAccess.hasPremium.value)
                if (collection.tracks.isEmpty()) {
                  // Nothing in it at all: nothing to play, nothing to sell.
                } else if (queue.isNotEmpty()) {
                  dependencies.soundPlayer.playFrom(queue, 0)
                } else {
                  actions.openPaywall(PaywallSource.LockedSound)
                }
              },
              onOpenCollectionList = actions.openCollectionList,
              refreshKey = account?.id,
              isFukuOnAir = pause.isFukuOnAir,
              onOpenFukuLounge = actions.openFukuLounge,
              onRefreshPause = dependencies.globalPause::start,
            )
          },
          gardenContent = { actions ->
            MindGardenHomeScreen(
              garden = dependencies.gardenStore,
              journal = dependencies.practiceJournal,
              // The coordinator titles the practice from resources, so only the
              // pattern is chosen here — iOS's `DeepSessionLibrary.balancingBreath`.
              onOpenSession = {
                actions.openDeepSession(
                  DeepSession(id = "balancing-breath", title = "", tagline = "", cycles = 6),
                )
              },
              // Both halves of the garden, together — iOS's pull refreshes the
              // garden snapshot and the practice journal side by side.
              onRefresh = {
                coroutineScope {
                  val garden = async { dependencies.gardenStore.refresh() }
                  val journal = async { dependencies.practiceJournal.refresh() }
                  garden.await()
                  journal.await()
                }
              },
            )
          },
          compassionContent = { openCause ->
            CompassionCoordinator(
              ledger = dependencies.heartLedger,
              give = dependencies::giveHearts,
              // One pull refreshes the garden, and the wallet rides it.
              onRefresh = { dependencies.gardenStore.refresh() },
              onOpenCause = openCause,
            )
          },
          compassionCauseContent = { causeId, onBack ->
            val cause = rememberCompassionContent().cause(causeId)
            if (cause != null) {
              CompassionCategoryScreen(
                cause = cause,
                ledger = dependencies.heartLedger,
                give = dependencies::giveHearts,
                onBack = onBack,
              )
            }
          },
          deepSessionContent = { session, onFinish ->
            DeepSessionCoordinator(
              session = session,
              onFinish = onFinish,
              chime = chime,
              onComplete = dependencies.practiceRewards::complete,
              onWitnessContinuity = dependencies.practiceRewards::witnessContinuity,
            )
          },
          fukuLoungeContent = { onJoin, onBack ->
            GlobalPauseLobbyScreen(
              session = dependencies.globalPause,
              scene = globeScene,
              fetchMessages = dependencies.pauseEvents::messages,
              soundPlayer = dependencies.soundPlayer,
              radio = loungeRadio,
              onJoin = onJoin,
              onBack = onBack,
            )
          },
          canJoinGlobalPause = { dependencies.globalPause.state.value.isMeditationLive },
          globalPauseContent = { visibility, onFinish ->
            // Fuku hands the room over: the lounge may still be underneath this
            // cover, and its set must not play under the meditation.
            LaunchedEffect(Unit) { loungeRadio.stop() }
            val context = LocalContext.current
            val audio = remember { GlobalPauseAudioPlayer(context.applicationContext, dependencies.http.mediaClient) }
            DisposableEffect(audio) { onDispose { audio.release() } }
            val account by dependencies.accountStore.account.collectAsStateWithLifecycle()
            GlobalPauseSessionCoordinator(
              session = dependencies.globalPause,
              scene = globeScene,
              audio = audio,
              snapshot = dependencies.pauseNightRewards::snapshot,
              receipt = dependencies.pauseNightRewards::receipt,
              witnessContinuity = dependencies.pauseNightRewards::witnessContinuity,
              memberName = account?.displayName,
              onFinish = onFinish,
              visibility = visibility,
              hydrate = dependencies.pauseNightRewards::hydrate,
            )
          },
        )
      }
    }
  }

  /**
   * Language, font size, display size and foldable changes are handled in
   * process (`configChanges`): Compose re-reads the configuration, and
   * nothing — not the launch beat, a running DEEP Session or an open Global
   * Pause — is torn down by a recreate.
   *
   * - **API 33+:** a language picked in the system's per-app settings now
   *   arrives here instead of recreating the activity, so it is adopted here.
   * - **API 26–32:** the activity reads through the base context
   *   [attachBaseContext] wrapped. That wrapper's configuration was copied
   *   whole as it was made, so the platform's rebase of it on a change can
   *   either keep stale values (the font scale and density it was made with)
   *   or, where the activity carries no override of its own, drop its locale
   *   altogether. Rather than lean on which, compare what the screens now read
   *   with what they should, and recreate when they disagree — the old path,
   *   kept only for the cases it is still needed. (A dark-mode toggle that
   *   leaves both intact changes nothing: DEEP is light-only.)
   */
  override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)
    val languageStore = (application as DeepApplication).dependencies.languageStore
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      languageStore.adoptSystemChoice()
      return
    }
    val reading = resources.configuration
    val language = languageStore.selection.value
    val staleLocale = reading.locales.get(0)?.language != language.resourceLanguageCode
    val staleScale = reading.fontScale != newConfig.fontScale || reading.densityDpi != newConfig.densityDpi
    if (staleLocale || staleScale) recreate()
  }
}

/**
 * The debug-only launch extra behind `AppDependencies.useMockSubscriptions`:
 * `adb shell am start -n <package>/io.appbeyond.freelance.deep.MainActivity
 * --ez deep.mockSubscriptions true`. A `const`, so it is inlined into the one
 * debug branch that reads it and leaves no trace in a release build.
 */
private const val MOCK_SUBSCRIPTIONS_EXTRA = "deep.mockSubscriptions"

/**
 * Which mock fixture to stand up — `--es deep.mockSubscriptions.variant
 * unreachable` (names in `MockSubscriptionStore.variant`). Debug builds only,
 * like [MOCK_SUBSCRIPTIONS_EXTRA].
 */
private const val MOCK_SUBSCRIPTIONS_VARIANT_EXTRA = "deep.mockSubscriptions.variant"
