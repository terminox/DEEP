package io.appbeyond.freelance.deep.feature.deepsession

import android.view.HapticFeedbackConstants
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsession.model.BreathEngine
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.breath
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.hush
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import kotlinx.coroutines.delay
import kotlin.time.Duration.Companion.seconds
import kotlin.time.DurationUnit

/**
 * The practice: an orb that swells with the breath, the phase cue beneath it, and
 * one soft control.
 *
 * A projection of [BreathEngine] — the clock lives there, this screen only
 * renders it. Two beats belong to the screen rather than the engine: the first
 * inhale never lands unannounced, so a short settling count runs before the
 * engine starts; and once the last exhale settles, the control fades away rather
 * than sitting there inviting a tap on a finished session.
 *
 * Ported from Deep/Deep/Features/DeepSession/Screens/DeepSessionView.swift.
 *
 * @param countdownSeconds seconds of settling before the first inhale. Previews
 *   pass 0 to pin a moment.
 */
@Composable
fun DeepSessionScreen(
  session: DeepSession,
  onFinished: () -> Unit,
  onLeave: () -> Unit,
  modifier: Modifier = Modifier,
  chime: ChimePlaying = SilentChime(),
  countdownSeconds: Int = 3,
) {
  val scope = rememberCoroutineScope()
  val engine = remember(session) { BreathEngine(session, scope) }
  val state by engine.state.collectAsStateWithLifecycle()
  val reduceMotion = rememberReduceMotion()
  val view = LocalView.current

  var countdown by remember { mutableStateOf<Int?>(countdownSeconds.takeIf { it > 0 }) }
  var confirmingLeave by remember { mutableStateOf(false) }

  val swell = remember { Animatable(0f) }

  // Keep the screen awake for the whole practice. Nobody should have to touch
  // the phone to stop it going dark mid-breath.
  DisposableEffect(Unit) {
    view.keepScreenOn = true
    onDispose { view.keepScreenOn = false }
  }

  // The bell is warmed a whole practice ahead, so the strike has no gap in it.
  LaunchedEffect(Unit) { chime.prepare() }

  // The settling count, then the engine starts.
  LaunchedEffect(session) {
    var remaining = countdown
    while (remaining != null && remaining > 0) {
      view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
      delay(1.seconds)
      remaining -= 1
      countdown = remaining.takeIf { it > 0 }
      if (remaining == 0) countdown = null
    }
    engine.begin()
  }

  // The breath itself.
  //
  // Compose gives this for free where SwiftUI does not: `Animatable.stop()`
  // leaves the value exactly where the animation had reached, so a pause freezes
  // the orb mid-flight. The iOS version has to sample the easing curve by hand
  // to work out where it was.
  LaunchedEffect(state.phase, countdown) {
    if (countdown != null) return@LaunchedEffect
    when (state.phase) {
      BreathEngine.Phase.Inhale -> {
        view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
        swell.animateTo(1f, breath(session.inhale.toDouble(DurationUnit.SECONDS).toFloat()))
      }

      BreathEngine.Phase.Exhale -> {
        view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
        swell.animateTo(0f, breath(session.exhale.toDouble(DurationUnit.SECONDS).toFloat()))
      }

      BreathEngine.Phase.Finished -> {
        chime.ring()
        swell.animateTo(0.6f, bloom())
      }
    }
  }

  LaunchedEffect(state.isPaused) {
    if (state.isPaused) swell.stop()
  }

  BackHandler { confirmingLeave = true }

  Box(
    modifier
      .fillMaxSize()
      .background(Color.moonCream),
  ) {
    AtmosphereBackground()

    Column(
      Modifier
        .fillMaxSize()
        .safeDrawingPadding()
        .padding(horizontal = Dp.edge),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.Center,
    ) {
      BreathingOrb(
        swell = if (reduceMotion) 0.75f else swell.value,
        // Under reduced motion the breath moves as light rather than as size.
        glow = if (reduceMotion) 0.55f + 0.45f * swell.value else 1f,
        modifier = Modifier.size(ORB_SIZE),
      )

      Spacer(Modifier.height(Dp.rhythm))

      CueBlock(
        countdown = countdown,
        phase = state.phase,
        cycle = state.cycle,
        cycles = session.cycles,
      )

      Spacer(Modifier.height(Dp.rhythm))

      // The control leaves once the practice is done — the coordinator carries
      // the flow onward from there, and a live button would invite a tap that
      // means nothing.
      val controlHidden = state.phase == BreathEngine.Phase.Finished || countdown != null
      AnimatedContent(
        targetState = controlHidden,
        transitionSpec = { fadeIn(bloom()) togetherWith fadeOut(bloom()) },
        label = "session-control",
      ) { hidden ->
        if (hidden) {
          Spacer(Modifier.height(CONTROL_HEIGHT))
        } else {
          TextButton(onClick = { engine.togglePaused() }) {
            Text(
              text = stringResource(
                if (state.isPaused) R.string.session_resume else R.string.session_pause
              ),
              style = DeepType.bodyMedium,
              color = Color.driftGrey,
            )
          }
        }
      }
    }
  }

  LaunchedEffect(state.phase) {
    if (state.phase == BreathEngine.Phase.Finished) {
      // Let the bell and the last settle land before handing over.
      delay(FINISH_HOLD)
      onFinished()
    }
  }

  DisposableEffect(Unit) { onDispose { engine.cancel() } }

  if (confirmingLeave) {
    AlertDialog(
      onDismissRequest = { confirmingLeave = false },
      containerColor = Color.moonCream,
      title = {
        Text(stringResource(R.string.session_leave_confirm), style = DeepType.displayTitle)
      },
      text = {
        Text(stringResource(R.string.session_leave_confirm_body), style = DeepType.body)
      },
      confirmButton = {
        TextButton(onClick = onLeave) {
          Text(stringResource(R.string.session_leave), style = DeepType.bodyMedium)
        }
      },
      dismissButton = {
        TextButton(onClick = { confirmingLeave = false }) {
          Text(stringResource(R.string.session_stay), style = DeepType.bodyMedium)
        }
      },
    )
  }
}

@Composable
private fun CueBlock(
  countdown: Int?,
  phase: BreathEngine.Phase,
  cycle: Int,
  cycles: Int,
) {
  Column(
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(6.dp),
    modifier = Modifier.fillMaxWidth(),
  ) {
    AnimatedContent(
      targetState = Triple(countdown, phase, cycle),
      transitionSpec = { fadeIn(hush()) togetherWith fadeOut(hush()) },
      label = "session-cue",
    ) { (count, currentPhase, currentCycle) ->
      Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
      ) {
        val cue = when {
          count != null -> count.toString()
          currentPhase == BreathEngine.Phase.Inhale -> stringResource(R.string.session_breathe_in)
          currentPhase == BreathEngine.Phase.Exhale -> stringResource(R.string.session_breathe_out)
          else -> stringResource(R.string.session_ending)
        }

        Text(
          text = cue,
          style = if (count != null) DeepType.counter else DeepType.displayTitle,
          color = Color.deepPlum,
          textAlign = TextAlign.Center,
        )

        if (count == null && currentPhase != BreathEngine.Phase.Finished) {
          Text(
            text = stringResource(R.string.session_round, currentCycle, cycles),
            style = DeepType.caption,
            color = Color.driftGrey,
            textAlign = TextAlign.Center,
          )
        }
      }
    }
  }
}

private val ORB_SIZE = 240.dp
private val CONTROL_HEIGHT = 48.dp
private val FINISH_HOLD = 2.seconds

@Preview(showBackground = true, name = "Mid-inhale")
@Composable
private fun DeepSessionScreenPreview() {
  DeepTheme {
    DeepSessionScreen(
      session = DeepSession(id = "preview", title = "Balancing breath", tagline = "", cycles = 6),
      onFinished = {},
      onLeave = {},
      countdownSeconds = 0,
    )
  }
}
