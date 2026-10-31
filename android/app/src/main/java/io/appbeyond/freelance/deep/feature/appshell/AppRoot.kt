package io.appbeyond.freelance.deep.feature.appshell

import android.util.Log
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.auth.TokenRefresher
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.globalpause.currentCardLift
import io.appbeyond.freelance.deep.feature.deepsound.player.MockSoundPlayer
import io.appbeyond.freelance.deep.feature.deepsound.player.SoundPlaying
import io.appbeyond.freelance.deep.feature.rewards.store.ListenReporting
import io.appbeyond.freelance.deep.feature.rewards.store.MockListenReporter
import io.appbeyond.freelance.deep.feature.deepsound.store.MockSoundLibrary
import io.appbeyond.freelance.deep.feature.deepsound.store.SoundLibrary
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockAccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingRemote
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingRemote
import io.appbeyond.freelance.deep.feature.playlist.store.MockPlaylistStore
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistStore
import io.appbeyond.freelance.deep.feature.reminders.store.MockReminderScheduler
import io.appbeyond.freelance.deep.feature.reminders.store.ReminderStore
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import java.time.Clock
import java.time.ZoneId
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
import java.util.UUID

/**
 * This process, as a value an activity can save. The launch beat records the
 * process it played in, so a recreated activity — anything `configChanges`
 * still lets through — opens straight on where it was instead of breathing
 * the launch again and re-running restore. After process death the stores are
 * empty again and the saved token no longer matches, so the beat (and the
 * restore it covers) runs as it must.
 */
private val PROCESS_LAUNCH = UUID.randomUUID().toString()

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
 * Deviation from iOS: every root destination crossfades on [hush]. iOS brings
 * the flow in on a `softDrift` whose veil is a blur; `SoftDrift` now exists in
 * `shared/transition/SoftDrift.kt`, but the root hand-offs have not been moved
 * onto it, so they keep the plain crossfade.
 *
 * @param awaitOnboardingLoaded suspends until [onboardingStore]'s first real
 *   load has landed, so a persisted "onboarding complete" is never missed for
 *   one frame.
 * @param soundPlayer paused as a practice begins — at Begin, not as the
 *   threshold opens: the threshold is an ordinary screen in the tab, but the
 *   session plays its own bell and breath, and a track underneath would talk
 *   over both. It stays loaded, so the mini player picks up where the member
 *   left off — iOS's `pause()` in `DeepSessionCoordinatorView.onAppear`.
 * @param listenReporter / soundLibrary / playlistStore handed on to the shell
 *   for the player's heart notices, DEEP Sound and the You tab's saved sounds.
 * @param syncRewards pulls the garden and wallet and syncs the practice
 *   journal (`AppDependencies.syncRewards`). Called as the shell is composed —
 *   which covers both a restored launch and a fresh sign-in or sign-up — and
 *   on every process foreground while it stays composed: iOS's `bootstrap()`,
 *   `.flow → .main` and scene-phase `.active` seams in one place.
 * @param flushBeforeLogOut / resetAccountState the rewards side of every
 *   exit, handed on to Settings, and the reset is also run here when the
 *   server rejects a restored session.
 * @param reminderStore / preferences the daily reminder and the language
 *   picker, handed on to Settings' preference screens.
 * @param compassionContent / compassionCauseContent the Compassion tab's root
 *   and its (parked) cause detail, handed on to the shell.
 * @param flowContent the onboarding and auth flow. A slot rather than a direct
 *   call so this file does not depend on the flow's wiring.
 * @param fukuLoungeContent Fuku's Lounge, handed on to the shell; its live card
 *   opens [globalPauseContent] over everything, while [canJoinGlobalPause]
 *   says the meditation is live.
 */
@Composable
fun AppRoot(
  accountStore: AccountStore,
  onboardingStore: OnboardingProgressStore,
  onboardingRemote: OnboardingRemote,
  awaitOnboardingLoaded: suspend () -> Unit,
  language: AppLanguage,
  reminderStore: ReminderStore,
  preferences: PreferenceActions,
  soundPlayer: SoundPlaying,
  listenReporter: ListenReporting,
  soundLibrary: SoundLibrary,
  playlistStore: PlaylistStore,
  syncRewards: () -> Unit,
  flushBeforeLogOut: suspend () -> Boolean,
  resetAccountState: suspend () -> Unit,
  modifier: Modifier = Modifier,
  flowContent: @Composable () -> Unit = {},
  homeContent: @Composable (actions: HomeActions) -> Unit = {},
  gardenContent: @Composable (actions: HomeActions) -> Unit = {},
  compassionContent: @Composable (openCause: (String) -> Unit) -> Unit = {},
  compassionCauseContent: @Composable (causeId: String, onBack: () -> Unit) -> Unit = { _, _ -> },
  deepSessionContent: @Composable (session: DeepSession, onFinish: () -> Unit) -> Unit =
    { _, _ -> },
  fukuLoungeContent: @Composable (onJoin: () -> Unit, onBack: () -> Unit) -> Unit = { _, _ -> },
  canJoinGlobalPause: () -> Boolean = { false },
  globalPauseContent: @Composable (visibility: AnimatedVisibilityScope, onFinish: () -> Unit) -> Unit =
    { _, _ -> },
) {
  // Saved with the activity, checked against this process (see
  // [PROCESS_LAUNCH]): a recreate keeps the launch behind it.
  var beatPlayedIn by rememberSaveable { mutableStateOf<String?>(null) }
  val beatAlreadyPlayed = beatPlayedIn == PROCESS_LAUNCH
  var restored by remember { mutableStateOf(beatAlreadyPlayed) }
  // The beat stays mounted (transparent) until dismissed, so its exhale is a
  // plain state animation that finishes over whatever surfaces beneath it.
  var beatExhaled by remember { mutableStateOf(beatAlreadyPlayed) }
  var beatDismissed by remember { mutableStateOf(beatAlreadyPlayed) }

  val account by accountStore.account.collectAsStateWithLifecycle()
  val onboarding by onboardingStore.state.collectAsStateWithLifecycle()
  val phase = rootPhase(
    restored = restored,
    signedIn = account != null,
    completedOnboarding = onboarding.hasCompletedOnboarding,
  )

  LaunchedEffect(Unit) {
    if (beatAlreadyPlayed) return@LaunchedEffect
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
              resetAccountState()
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
    beatPlayedIn = PROCESS_LAUNCH
  }

  // The running practice, presented over the whole shell from Begin on its
  // threshold (which stays on the tab's stack beneath). Its closing bell is
  // owned above this, by `MainActivity`, so it rings on as the cover leaves.
  var runningSession by remember { mutableStateOf<DeepSession?>(null) }
  // The last practice shown, held through the cover's exit fade so the fade
  // has something to fade — `runningSession` is already null by then.
  var shownSession by remember { mutableStateOf<DeepSession?>(null) }
  // The live Global Pause, presented over the shell the same way.
  var pauseOpen by remember { mutableStateOf(false) }
  LaunchedEffect(phase) {
    if (phase != RootPhase.Main) {
      runningSession = null
      pauseOpen = false
    }
  }
  val lift = currentCardLift

  DeepTheme {
    Box(modifier.fillMaxSize().background(Color.moonCream)) {
      // The one persistent backdrop. It rests while the opaque shell covers it,
      // so the drift costs nothing per frame once you are in the app.
      AtmosphereBackground(animated = phase != RootPhase.Main)

      // Each phase is its own composition: leaving Main disposes the shell and
      // all of its remembered state, so a log out followed by a sign-in opens a
      // fresh shell on Home rather than on the last member's Settings.
      //
      // While a full-screen presentation covers the shell, the shell leaves
      // the accessibility tree: TalkBack could otherwise reach the lounge, its
      // feed and all five tabs under the live session (QA round 1, B4) — the
      // modal semantics iOS's full-screen cover gets for free.
      val covered = runningSession != null || pauseOpen
      // Held, not only paused, while either is up. Android puts DEEP Sound on
      // the lock screen, the notification and a headset's buttons, and any of
      // them would otherwise start the track under the breath — or, in Global
      // Pause, take audio focus from the meditation. iOS has none of those
      // controls for DEEP Sound, so a pause is enough there. Released on
      // dispose too: the player outlives this activity, and a hold left behind
      // would refuse every play for the rest of the process.
      DisposableEffect(covered) {
        soundPlayer.holdPlayback(covered)
        onDispose { soundPlayer.holdPlayback(false) }
      }
      AnimatedContent(
        targetState = phase,
        transitionSpec = { fadeIn(hush()) togetherWith fadeOut(hush()) },
        label = "root-phase",
        modifier = if (covered) Modifier.clearAndSetSemantics {} else Modifier,
      ) { target ->
        when (target) {
          RootPhase.Restoring -> Box(Modifier.fillMaxSize())
          RootPhase.Flow -> flowContent()
          RootPhase.Main -> {
            // The process's ON_START, not the activity's: a rotation or a
            // language change recreates the activity without the member ever
            // leaving. ON_START is replayed as the observer registers, so this
            // one effect also fires as the shell first composes — once per
            // entry into Main, whether from the launch beat or a fresh sign-in,
            // and never twice at cold start.
            LifecycleEventEffect(Lifecycle.Event.ON_START, ProcessLifecycleOwner.get()) {
              syncRewards()
            }
            MainShellCoordinator(
              accountStore = accountStore,
              onboardingStore = onboardingStore,
              language = language,
              reminderStore = reminderStore,
              preferences = preferences,
              soundPlayer = soundPlayer,
              listenReporter = listenReporter,
              soundLibrary = soundLibrary,
              playlistStore = playlistStore,
              flushBeforeLogOut = flushBeforeLogOut,
              resetAccountState = resetAccountState,
              homeContent = homeContent,
              gardenContent = gardenContent,
              compassionContent = compassionContent,
              compassionCauseContent = compassionCauseContent,
              // A guided breath and ambient audio don't mix: the practice
              // begins in silence. The track stays loaded, so the mini player
              // is waiting on return.
              onBeginDeepSession = {
                if (runningSession == null) {
                  soundPlayer.pause()
                  shownSession = it
                  runningSession = it
                }
              },
              deepSessionRunning = runningSession != null,
              // Only while the meditation is live — outside it the card rests,
              // its caption already carrying the countdown. The session owns
              // its own audio, so the shared player pauses (its track stays
              // loaded for the mini player to resume), as iOS's yieldAudio.
              onOpenGlobalPause = {
                if (!pauseOpen && canJoinGlobalPause()) {
                  soundPlayer.pause()
                  pauseOpen = true
                }
              },
              fukuLoungeContent = fukuLoungeContent,
              miniPlayerSuppressed = runningSession != null || pauseOpen,
            )
          }
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
      val session = runningSession ?: shownSession
      AnimatedVisibility(
        visible = runningSession != null,
        enter = fadeIn(hush()) + slideInVertically(hush()) { it / 24 },
        exit = fadeOut(hush()),
      ) {
        if (session != null) {
          // Opaque, as iOS's full-screen cover is. Every stage paints its own
          // translucent atmosphere and they crossfade, so without this the
          // shell showed through at mid-fade — the Garden's hero and cards
          // ghosting behind the practice as it gave way to the reward ritual.
          Box(
            Modifier
              .fillMaxSize()
              .background(Color.moonCream)
              .blocksTouchesBeneath(),
          ) {
            deepSessionContent(session) { runningSession = null }
          }
        }
      }

      // The live Global Pause, over the whole shell. Its presentation is the
      // card lift's seam (`GlobalPauseCardLift`): a crossfade this week, the
      // card becoming the session's backdrop in week 7.
      AnimatedVisibility(
        visible = pauseOpen,
        enter = lift.enter,
        exit = lift.exit,
      ) {
        val visibility = this
        Box(Modifier.fillMaxSize().blocksTouchesBeneath()) {
          globalPauseContent(visibility) { pauseOpen = false }
        }
      }
    }
  }
}

/**
 * Makes a full-screen cover the end of the line for touches, as iOS's
 * full-screen presentations are: without it a tap on the cover's empty
 * atmosphere fell through to the tab bar and shell beneath, which are only
 * siblings here.
 *
 * Nothing is consumed — the cover's own controls see every event exactly as
 * before. Being hit is the whole job: Compose stops hit-testing siblings
 * below the first one whose pointer input is hit.
 */
private fun Modifier.blocksTouchesBeneath(): Modifier = pointerInput(Unit) {
  awaitPointerEventScope {
    while (true) awaitPointerEvent()
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
    reminderStore = remember {
      ReminderStore(MockReminderScheduler(), InMemoryBlobStore(), Clock.systemDefaultZone()) { ZoneId.systemDefault() }
    },
    preferences = PreferenceActions.none,
    soundPlayer = MockSoundPlayer.idle(),
    listenReporter = MockListenReporter(),
    soundLibrary = remember { MockSoundLibrary.loaded },
    playlistStore = MockPlaylistStore.empty,
    syncRewards = {},
    flushBeforeLogOut = { true },
    resetAccountState = {},
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
    reminderStore = remember {
      ReminderStore(MockReminderScheduler(), InMemoryBlobStore(), Clock.systemDefaultZone()) { ZoneId.systemDefault() }
    },
    preferences = PreferenceActions.none,
    soundPlayer = MockSoundPlayer.idle(),
    listenReporter = MockListenReporter(),
    soundLibrary = remember { MockSoundLibrary.loaded },
    playlistStore = MockPlaylistStore.empty,
    syncRewards = {},
    flushBeforeLogOut = { true },
    resetAccountState = {},
    flowContent = { TabPlaceholderScreen(DeepTab.Compassion) },
  )
}
