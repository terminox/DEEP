package io.appbeyond.freelance.deep

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.appbeyond.freelance.deep.feature.appshell.AppRoot
import io.appbeyond.freelance.deep.feature.deepsession.DeepSessionCoordinator
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsound.player.play
import io.appbeyond.freelance.deep.feature.globalpause.GlobalPauseHomeScreen
import io.appbeyond.freelance.deep.feature.mindgarden.MindGardenHomeScreen
import io.appbeyond.freelance.deep.feature.onboarding.OnboardingCoordinator
import io.appbeyond.freelance.deep.networking.LocalVideoCache
import io.appbeyond.freelance.deep.networking.VideoCache
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

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

  override fun onCreate(savedInstanceState: Bundle?) {
    installSplashScreen()
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)

    val dependencies = (application as DeepApplication).dependencies
    // Remote stage footage fills this as it plays, so the Garden's hero loops
    // from disk on every visit after the first — iOS's `VideoCache`.
    val videoCache = VideoCache.shared(this, dependencies.http.mediaClient)

    setContent {
      CompositionLocalProvider(LocalVideoCache provides videoCache) {
        AppRoot(
          accountStore = dependencies.accountStore,
          onboardingStore = dependencies.onboardingStore,
          onboardingRemote = dependencies.onboardingRemote,
          awaitOnboardingLoaded = dependencies::awaitOnboardingLoaded,
          language = dependencies.language,
          soundPlayer = dependencies.soundPlayer,
          soundLibrary = dependencies.soundLibrary,
          playlistStore = dependencies.playlistStore,
          syncRewards = dependencies::syncRewards,
          flushPracticeJournal = dependencies::flushPracticeJournal,
          resetRewardsState = dependencies::resetRewardsState,
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
          deepSessionContent = { session, onFinish ->
            DeepSessionCoordinator(
              session = session,
              onFinish = onFinish,
              onComplete = dependencies.practiceRewards::complete,
              onWitnessContinuity = dependencies.practiceRewards::witnessContinuity,
            )
          },
        )
      }
    }
  }
}
