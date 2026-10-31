package io.appbeyond.freelance.deep.feature.deepsession

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsession.model.BreathEngine
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.rewards.model.RewardReceipt
import io.appbeyond.freelance.deep.feature.rewards.screens.RewardRitualScreen
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.hush
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlin.math.roundToInt
import kotlin.time.Duration.Companion.seconds

/** The stages of a running practice: the breath, then what it grew. */
private sealed interface SessionStage {
  data object Practice : SessionStage
  data class Completion(val receipt: RewardReceipt) : SessionStage
}

/**
 * Owns one run of a DEEP Session: the practice, then the reward ritual, then
 * out. Presented over the whole shell — tab bar and mini player included —
 * from Begin on the threshold ([DeepSessionIntroScreen]), which stays on the
 * launching tab's stack underneath, so closing drifts straight back onto it.
 *
 * A coordinator in the project's sense: it owns the stage switch, the
 * [BreathEngine], the finish handshake and recording the practice, and carries
 * no styling of its own. Ported from
 * Deep/Deep/Features/DeepSession/DeepSessionCoordinatorView.swift.
 *
 * - **Recorded the instant the engine finishes**, not after the settle: the
 *   bell is struck, the practice and both rewards are banked, and only then
 *   does the last exhale get its one-second hold before the ritual blooms in.
 *   So closing from the finished screen — which asks nothing — still counts.
 *   Only a practice carried through reaches the end, so leaving early leaves
 *   in silence with nothing banked.
 * - **Leaving the app settles the practice into a pause**; resuming stays the
 *   member's own gesture (iOS's `scenePhase == .background`, here ON_STOP).
 *   A practice still in its settling count is left to the screen, which
 *   restarts the count on return — pausing an engine that has not begun would
 *   strand it paused once the count hands over.
 *
 * The bell is [chime], owned above this presentation: it rings for close to
 * four seconds, long enough for a member to tap through the ritual and close
 * while it is still sounding, and a chime owned here would be torn down
 * mid-ring as the cover leaves.
 *
 * @param session the practice at the length chosen on the threshold.
 * @param onComplete records the finished practice and returns what it earned
 *   (`PracticeRewards.complete`). Null — previews — closes after the settle.
 * @param onWitnessContinuity stamps today's continuity beat as the ritual shows it.
 */
@Composable
fun DeepSessionCoordinator(
  session: DeepSession,
  onFinish: () -> Unit,
  modifier: Modifier = Modifier,
  chime: ChimePlaying = SilentChime(),
  onComplete: (suspend (title: String, durationSeconds: Int) -> RewardReceipt)? = null,
  onWitnessContinuity: suspend () -> Unit = {},
) {
  val scope = rememberCoroutineScope()
  val engine = remember(session) { BreathEngine(session, scope) }
  var stage by remember { mutableStateOf<SessionStage>(SessionStage.Practice) }
  val currentOnFinish by rememberUpdatedState(onFinish)
  val currentOnComplete by rememberUpdatedState(onComplete)

  // The journal names the practice itself, not the card that opened it: iOS
  // records `DeepSessionLibrary.balancingBreath`'s title, and a member's pulled
  // history mixes both platforms' rows. One practice ships, so it is named here.
  val journalTitle = stringResource(R.string.deepsound_balancing_breath_title)

  // Warmed a whole practice ahead of the strike, so the bell that ends the
  // practice is not the thing waking the audio stack on the last exhale.
  LaunchedEffect(chime) { chime.prepare() }

  DisposableEffect(engine) { onDispose { engine.cancel() } }

  LifecycleEventEffect(Lifecycle.Event.ON_STOP) {
    // Null before the first inhale (the screen owns the settling count) and
    // once finished; `pause` is a no-op while already paused.
    if (engine.remainingInPhase != null) engine.pause()
  }

  // Banks the practice once, the moment it finishes. `complete` runs
  // NonCancellable, so the record survives this cover leaving mid-settle.
  LaunchedEffect(engine) {
    engine.state.first { it.phase == BreathEngine.Phase.Finished }
    // The bell marks the breath, not the exit: struck ahead of everything
    // below, so no bookkeeping sits between the last exhale and the sound.
    chime.ring()
    val settle = launch { delay(FINISH_HOLD) }
    val record = currentOnComplete
    if (record == null) {
      settle.join()
      currentOnFinish()
      return@LaunchedEffect
    }
    val seconds = (session.duration.inWholeMilliseconds / 1000.0).roundToInt()
    val receipt = record(journalTitle, seconds)
    // Let the final exhale settle before the first reward blooms in.
    settle.join()
    stage = SessionStage.Completion(receipt)
  }

  AnimatedContent(
    targetState = stage,
    transitionSpec = { fadeIn(hush()) togetherWith fadeOut(hush()) },
    label = "session-stage",
    modifier = modifier,
  ) { current ->
    when (current) {
      SessionStage.Practice -> DeepSessionScreen(engine = engine, onClose = onFinish)

      is SessionStage.Completion -> RewardRitualScreen(
        receipt = current.receipt,
        // A return when today's practice is what extended the run; otherwise
        // the run is witnessed as it stands — iOS's `ContinuityRewardView.headline`.
        continuityHeadline = stringResource(
          if (current.receipt.returnedToday) {
            R.string.reward_continuity_headline_returned
          } else {
            R.string.reward_continuity_headline_continues
          },
        ),
        onWitnessContinuity = onWitnessContinuity,
        onFinish = onFinish,
      )
    }
  }
}

/** The last exhale's settle before the ritual — iOS's one second. */
private val FINISH_HOLD = 1.seconds

@Preview(showBackground = true)
@Composable
private fun DeepSessionCoordinatorPreview() {
  DeepTheme {
    DeepSessionCoordinator(
      session = DeepSession(id = "preview", title = "", tagline = "", cycles = 6),
      onFinish = {},
      chime = SilentChime(),
    )
  }
}
