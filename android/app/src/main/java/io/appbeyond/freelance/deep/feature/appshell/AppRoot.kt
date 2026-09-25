package io.appbeyond.freelance.deep.feature.appshell

import android.util.Log
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.auth.TokenRefresher
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockAccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingRemote
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingRemote
import io.appbeyond.freelance.deep.networking.DeepApiException
import io.appbeyond.freelance.deep.onboarding.model.OnboardingState
import io.appbeyond.freelance.deep.onboarding.model.RootPhase
import io.appbeyond.freelance.deep.onboarding.model.rootPhase
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.BreatheLoadingView
import io.appbeyond.freelance.deep.shared.localization.AppLanguage
import io.appbeyond.freelance.deep.theme.BREATHE_FLOOR_MILLIS
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.hush
import io.appbeyond.freelance.deep.theme.moonCream
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * The launch beat's staged send-off. Private for the reason iOS keeps its
 * `Handoff` enum private in `AppRootView.swift`: these values choreograph only
 * this screen's hand-off; the exhale itself keeps the `exhale` motion token's
 * tempo.
 */
private object Handoff {
  /** The quiet between the text beginning its exhale and the destination surfacing. */
  const val STILLNESS_MILLIS = 550L

  /** Margin after the destination starts arriving before the invisible beat is unmounted. */
  const val SETTLE_MILLIS = 300L
}

/**
 * The app's composition root and phase machine.
 *
 * Decides among three phases, exactly as `AppRootView.swift` does, through the
 * pure [rootPhase]:
 *  - **Restoring** — a calm, breathing launch beat while any saved session is
 *    confirmed with the backend, so a returning member never flashes the
 *    welcome screen.
 *  - **Flow** — onboarding and auth ([flowContent]).
 *  - **Main** — the tab shell, once signed in *and* onboarding is complete.
 *
 * One moonCream and atmosphere backdrop persists beneath every phase, so
 * hand-offs crossfade atmosphere to atmosphere and never dip to white.
 *
 * Leaving the beat is the iOS staged exhale, conducted by the bootstrap rather
 * than left to an exit transition: the text exhales in place
 * ([BreatheLoadingView]'s `exhaled`), the destination surfaces beneath its
 * tail after [Handoff.STILLNESS_MILLIS] of stillness, and the by-then
 * invisible beat is unmounted [Handoff.SETTLE_MILLIS] later. iOS stages it
 * because SwiftUI skips removal transitions on a self-updating timeline;
 * Compose would not, but the choreography is the design, so it is kept.
 *
 * The beat holds for [BREATHE_FLOOR_MILLIS] even when there is nothing to wait
 * for. A fast start that flashes a loading state for 80ms is worse than one
 * that breathes once.
 *
 * Everything stateful arrives as a parameter — `MainActivity` is the one place
 * that reads `AppDependencies` — so the preview runs on mocks.
 *
 * Deviation from iOS: every destination crossfades on [hush]. iOS brings the
 * flow in on a `softDrift` whose veil is a blur, and `Modifier.blur` is a no-op
 * below API 31; `SoftDrift` is not ported yet.
 *
 * @param awaitOnboardingLoaded suspends until [onboardingStore]'s first real
 *   load has landed, so a persisted "onboarding complete" is never missed for
 *   one frame.
 * @param flowContent the onboarding and auth flow. A slot rather than a direct
 *   call so this file does not depend on the flow's wiring.
 */
@Composable
fun AppRoot(
  accountStore: AccountStore,
  onboardingStore: OnboardingProgressStore,
  onboardingRemote: OnboardingRemote,
  awaitOnboardingLoaded: suspend () -> Unit,
  language: AppLanguage,
  modifier: Modifier = Modifier,
  flowContent: @Composable () -> Unit = {},
  homeContent: @Composable (onOpenDeepSession: (DeepSession) -> Unit) -> Unit = {},
  deepSessionContent: @Composable (session: DeepSession, onFinish: () -> Unit) -> Unit =
    { _, _ -> },
) {
  var restored by remember { mutableStateOf(false) }
  // The beat stays mounted (transparent) until dismissed, so its exhale is a
  // plain state animation that finishes over whatever surfaces beneath it.
  var beatExhaled by remember { mutableStateOf(false) }
  var beatDismissed by remember { mutableStateOf(false) }

  val account by accountStore.account.collectAsStateWithLifecycle()
  val onboarding by onboardingStore.state.collectAsStateWithLifecycle()
  val phase = rootPhase(
    restored = restored,
    signedIn = account != null,
    completedOnboarding = onboarding.hasCompletedOnboarding,
  )

  LaunchedEffect(Unit) {
    // Whatever happens in here, the beat must end: a launch that throws and
    // never flips `restored` is a breathing screen the member can only escape
    // by killing the app. Cancellation is the one thing let through — it means
    // this composition is gone, and there is no beat left to end.
    try {
      coroutineScope {
        // Hold the breathing beat at least this long, however fast restore
        // runs — a flash of the loading screen reads as a glitch, not a breath.
        val floor = launch { delay(BREATHE_FLOOR_MILLIS) }
        val onboardingLoaded = async { awaitOnboardingLoaded() }
        accountStore.restore()
        onboardingLoaded.await()
        if (accountStore.account.value != null) {
          // The server's copy wins over this phone's: a member who finished
          // onboarding on another install must land in the shell here too.
          try {
            val profile = onboardingRemote.fetchProfile()
            onboardingStore.hydrate(
              quizAnswers = profile.quizAnswers,
              mindTree = profile.mindTree,
              completed = profile.completed,
            )
          } catch (cancelled: CancellationException) {
            throw cancelled
          } catch (rejected: DeepApiException) {
            // A refusal is the server saying this session is over, even though
            // `/me` let it through a moment ago: sign out exactly as Settings
            // does, answers and all. An outage — offline, a timeout, a 5xx —
            // keeps what is on disk; restore never blocks on the network.
            if (TokenRefresher.isAuthRejection(rejected)) {
              accountStore.logOut()
              onboardingStore.reset()
            }
          } catch (_: Exception) {
            // A local write that failed: keep what is on disk and carry on.
          }
        }
        floor.join()
      }
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (unexpected: Exception) {
      Log.w("AppRoot", "Launch restore failed; leaving the beat with local state.", unexpected)
    }
    beatExhaled = true
    delay(Handoff.STILLNESS_MILLIS)
    restored = true
    delay(Handoff.SETTLE_MILLIS)
    beatDismissed = true
  }

  // Owned here, above the shell, for the reason the iOS side owns its chime
  // outside the presentation: the practice's closing bell rings for several
  // seconds and has to outlive the screen being dismissed.
  var runningSession by remember { mutableStateOf<DeepSession?>(null) }
  LaunchedEffect(phase) {
    if (phase != RootPhase.Main) runningSession = null
  }

  DeepTheme {
    Box(modifier.fillMaxSize().background(Color.moonCream)) {
      // The one persistent backdrop. It rests while the opaque shell covers it,
      // so the drift costs nothing per frame once you are in the app.
      AtmosphereBackground(animated = phase != RootPhase.Main)

      // Each phase is its own composition: leaving Main disposes the shell and
      // all of its remembered state, so a log out followed by a sign-in opens a
      // fresh shell on Home rather than on the last member's Settings.
      AnimatedContent(
        targetState = phase,
        transitionSpec = { fadeIn(hush()) togetherWith fadeOut(hush()) },
        label = "root-phase",
      ) { target ->
        when (target) {
          RootPhase.Restoring -> Box(Modifier.fillMaxSize())
          RootPhase.Flow -> flowContent()
          RootPhase.Main -> MainShellCoordinator(
            accountStore = accountStore,
            onboardingStore = onboardingStore,
            language = language,
            homeContent = homeContent,
            onOpenDeepSession = { runningSession = it },
          )
        }
      }

      // Above the destination, so the exhaling text finishes over whatever
      // surfaces beneath it. No backdrop of its own: the persistent one above
      // is already drawn, and a second would double the wash.
      if (!beatDismissed) {
        BreatheLoadingView(drawsBackdrop = false, exhaled = beatExhaled)
      }

      // The practice presents over the whole shell, tab bar included — which on
      // Android is simply a sibling in the same tree. The iOS equivalent needs a
      // zero-size UIViewControllerRepresentable that walks up the controller
      // hierarchy to find something able to present; none of that exists here.
      val session = runningSession
      AnimatedVisibility(
        visible = session != null,
        enter = fadeIn(hush()) + slideInVertically(hush()) { it / 24 },
        exit = fadeOut(hush()),
      ) {
        if (session != null) {
          deepSessionContent(session) { runningSession = null }
        }
      }
    }
  }
}

@Preview(showBackground = true, name = "App root — returning member")
@Composable
private fun AppRootPreview() {
  AppRoot(
    accountStore = MockAccountStore.emailUser,
    onboardingStore = MockOnboardingProgressStore(OnboardingState.Fresh.completed()),
    onboardingRemote = MockOnboardingRemote(),
    awaitOnboardingLoaded = {},
    language = AppLanguage.English,
    homeContent = { TabPlaceholderScreen(DeepTab.Home) },
  )
}

@Preview(showBackground = true, name = "App root — first launch")
@Composable
private fun AppRootFirstLaunchPreview() {
  AppRoot(
    accountStore = MockAccountStore.signedOut,
    onboardingStore = MockOnboardingProgressStore.fresh,
    onboardingRemote = MockOnboardingRemote(),
    awaitOnboardingLoaded = {},
    language = AppLanguage.English,
    flowContent = { TabPlaceholderScreen(DeepTab.Garden) },
  )
}
