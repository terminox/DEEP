package io.appbeyond.freelance.deep

import android.content.Context
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
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
import io.appbeyond.freelance.deep.feature.deepsession.DeepSessionCoordinator
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsound.player.play
import io.appbeyond.freelance.deep.feature.globalpause.GlobalPauseHomeScreen
import io.appbeyond.freelance.deep.feature.globalpause.GlobalPauseLobbyScreen
import io.appbeyond.freelance.deep.feature.globalpause.GlobalPauseSessionCoordinator
import io.appbeyond.freelance.deep.feature.globalpause.audio.GlobalPauseAudioPlayer
import io.appbeyond.freelance.deep.feature.globalpause.EarthCardLift
import io.appbeyond.freelance.deep.feature.globalpause.LocalGlobalPauseCardLift
import io.appbeyond.freelance.deep.feature.globalpause.globe.EarthGlobeRendering
import io.appbeyond.freelance.deep.feature.globalpause.globe.GlobeFlight
import io.appbeyond.freelance.deep.feature.globalpause.globe.GlobeScene
import io.appbeyond.freelance.deep.feature.globalpause.globe.LocalGlobeRendering
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.feature.mindgarden.MindGardenHomeScreen
import io.appbeyond.freelance.deep.feature.onboarding.OnboardingCoordinator
import io.appbeyond.freelance.deep.networking.LocalVideoCache
import io.appbeyond.freelance.deep.networking.VideoCache
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
    installSplashScreen()
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)

    val dependencies = (application as DeepApplication).dependencies

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
      CompositionLocalProvider(
        LocalVideoCache provides videoCache,
        LocalGlobeRendering provides globeRendering,
        LocalGlobalPauseCardLift provides cardLift,
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
          soundLibrary = dependencies.soundLibrary,
          playlistStore = dependencies.playlistStore,
          syncRewards = dependencies::syncRewards,
          flushPracticeJournal = dependencies::flushPracticeJournal,
          resetAccountState = dependencies::resetAccountState,
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
              // iOS's home tiles start their collection outright, with no detail
              // screen between the tap and the sound.
              onPlayCollection = { dependencies.soundPlayer.play(it) },
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
              onJoin = onJoin,
              onBack = onBack,
            )
          },
          canJoinGlobalPause = { dependencies.globalPause.state.value.isMeditationLive },
          globalPauseContent = { visibility, onFinish ->
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
            )
          },
        )
      }
    }
  }
}
