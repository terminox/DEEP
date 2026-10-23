package io.appbeyond.freelance.deep.feature.deepsession

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.hideFromAccessibility
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsession.model.BreathEngine
import io.appbeyond.freelance.deep.feature.deepsession.model.BreathEngine.Phase
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsession.model.SessionTimeLeft
import io.appbeyond.freelance.deep.feature.deepsound.PlayerIcons
import io.appbeyond.freelance.deep.feature.globalpause.components.GlobalPauseIcons
import io.appbeyond.freelance.deep.feature.profile.DeepConfirmDialog
import io.appbeyond.freelance.deep.feature.profile.DialogAction
import io.appbeyond.freelance.deep.feature.profile.HeaderIconButton
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
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softLilac
import io.appbeyond.freelance.deep.theme.softPress
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds
import kotlin.time.DurationUnit

/**
 * The practice: a full-bleed atmosphere with the orb at centre, the phase cue
 * beneath it, and one soft control.
 *
 * A projection of [BreathEngine] — the engine keeps time (and is owned by
 * [DeepSessionCoordinator], as iOS's coordinator owns it), this screen only
 * breathes. Two beats belong to the screen rather than the engine: the first
 * inhale never lands unannounced, so a short settling count runs before the
 * engine starts; and once the last exhale settles the control fades away, as
 * the coordinator carries the flow into its completion beat on its own.
 *
 * Leaving mid-practice asks first, and the breath freezes under the question
 * so nothing moves while the member decides; "Keep breathing" resumes unless
 * they had paused it themselves. The settling count and the finished settle
 * hold nothing to lose, so the close button and back leave them directly.
 *
 * Coming back from the background mid-count restarts the count rather than
 * letting it slam into the first inhale — iOS's `scenePhase` branch, on the
 * activity's ON_STOP / ON_START.
 *
 * Ported from Deep/Deep/Features/DeepSession/Screens/DeepSessionView.swift.
 * VoiceOver's `AccessibilityNotification.Announcement`s become one polite
 * live region over the cue: "Settling in. 3", then each count, then each cue.
 *
 * @param countdownSeconds seconds of settling before the first inhale. Previews
 *   pass 0 to pin a moment.
 */
@Composable
fun DeepSessionScreen(
  engine: BreathEngine,
  onClose: () -> Unit,
  modifier: Modifier = Modifier,
  countdownSeconds: Int = 3,
) {
  val scope = rememberCoroutineScope()
  val state by engine.state.collectAsStateWithLifecycle()
  val reduceMotion = rememberReduceMotion()
  val haptics = LocalHapticFeedback.current
  val view = LocalView.current
  val resources = LocalResources.current
  val currentOnClose by rememberUpdatedState(onClose)

  /** The orb's presented fullness, driven by phase changes. */
  val swell = remember { Animatable(0f) }
  /** The orb's presence under reduced motion — the breath as light, not size. */
  val glow = remember { Animatable(1f) }
  /** The settling count still to show; null once breathing has begun. */
  var countdown by remember { mutableStateOf(countdownSeconds.takeIf { it > 0 }) }
  /** What the live region says next — iOS's announcements. */
  var announcement by remember { mutableStateOf("") }
  var countdownJob by remember { mutableStateOf<Job?>(null) }
  var hasBegun by remember { mutableStateOf(false) }
  var confirmingLeave by remember { mutableStateOf(false) }
  var wasPausedBeforeConfirm by remember { mutableStateOf(false) }

  // Keep the screen awake for the whole practice. Nobody should have to touch
  // the phone to stop it going dark mid-breath.
  DisposableEffect(view) {
    view.keepScreenOn = true
    onDispose { view.keepScreenOn = false }
  }

  /**
   * Carries the orb towards the new phase's target at that phase's own tempo,
   * on the breath curve. Under reduced motion the orb holds still and breathes
   * as light instead. `animateTo` cancels whatever motion was in flight.
   */
  fun breathe(into: Phase) {
    scope.launch {
      if (reduceMotion) {
        swell.snapTo(REDUCED_SWELL)
        when (into) {
          Phase.Inhale -> glow.animateTo(1f, breath(engine.session.inhale.seconds()))
          Phase.Exhale -> glow.animateTo(REDUCED_GLOW_REST, breath(engine.session.exhale.seconds()))
          Phase.Finished -> glow.animateTo(1f, bloom())
        }
      } else {
        when (into) {
          Phase.Inhale -> swell.animateTo(1f, breath(engine.session.inhale.seconds()))
          Phase.Exhale -> swell.animateTo(0f, breath(engine.session.exhale.seconds()))
          Phase.Finished -> swell.animateTo(FINISHED_SWELL, bloom())
        }
      }
    }
  }

  /**
   * Begins the practice — after the settling count when one is configured,
   * immediately otherwise. Also the re-entry point when the app comes back
   * mid-count.
   */
  fun startCountdown() {
    if (countdownSeconds <= 0 || engine.state.value.phase == Phase.Finished) {
      countdown = null
      hasBegun = true
      breathe(engine.state.value.phase)
      engine.begin()
      return
    }

    countdown = countdownSeconds
    announcement = resources.getString(R.string.session_settling_in_announcement, countdownSeconds)
    haptics.performHapticFeedback(HapticFeedbackType.SegmentFrequentTick)
    val gather = breath<Float>(countdownSeconds.toFloat())
    scope.launch {
      if (reduceMotion) {
        swell.snapTo(REDUCED_SWELL)
        glow.snapTo(REDUCED_GLOW_REST)
        glow.animateTo(REDUCED_GLOW_GATHERED, gather)
      } else {
        // The orb gathers slightly, so the first inhale can fill from it.
        swell.animateTo(GATHERED_SWELL, gather)
      }
    }
    countdownJob = scope.launch {
      for (count in countdownSeconds - 1 downTo 1) {
        delay(1.seconds)
        countdown = count
        announcement = count.toString()
        // A lighter tick for each settling count; the hand-off into the first
        // inhale stays silent so the breath itself makes the first real mark.
        haptics.performHapticFeedback(HapticFeedbackType.SegmentFrequentTick)
      }
      delay(1.seconds)
      countdown = null
      countdownJob = null
      hasBegun = true
      breathe(Phase.Inhale)
      engine.begin()
      announcement = resources.getString(cueText(Phase.Inhale, engine.state.value.isPaused))
    }
  }

  // ON_START is replayed as the observer registers, so this both opens the
  // practice and restarts a count the background cut short.
  LifecycleEventEffect(Lifecycle.Event.ON_START) {
    if (!hasBegun && countdownJob == null) startCountdown()
  }
  // A suspended delay fires the instant the app returns, which would slam
  // straight into the first inhale — cancel the count instead.
  LifecycleEventEffect(Lifecycle.Event.ON_STOP) {
    if (countdown != null) {
      countdownJob?.cancel()
      countdownJob = null
    }
  }

  val cue = cueText(state.phase, state.isPaused)
  val cueLine = stringResource(cue)
  val caption = captionText(state, engine)

  // The two collectors below live for the whole practice, so they reach the
  // orb through these: reduced motion is read live, and switching it on
  // mid-practice must stop the orb swelling from the next turn.
  val currentBreathe by rememberUpdatedState(::breathe)
  val currentReduceMotion by rememberUpdatedState(reduceMotion)

  // Each turn of the breath, and each pause or resume: move the orb, mark the
  // turn with a soft tap so the practice works with eyes closed (inhale a
  // little firmer than exhale, so the pair reads as rise and release), and
  // speak the cue.
  LaunchedEffect(engine) {
    engine.state.map { it.phase }.distinctUntilChanged().drop(1).collect { phase ->
      currentBreathe(phase)
      haptics.performHapticFeedback(
        when (phase) {
          Phase.Inhale -> HapticFeedbackType.VirtualKey
          Phase.Exhale -> HapticFeedbackType.SegmentTick
          Phase.Finished -> HapticFeedbackType.Confirm
        },
      )
      announcement = resources.getString(cueText(phase, engine.state.value.isPaused))
    }
  }
  LaunchedEffect(engine) {
    engine.state.map { it.isPaused }.distinctUntilChanged().drop(1).collect { isPaused ->
      val phase = engine.state.value.phase
      // Compose gives this for free where SwiftUI does not: `stop()` leaves
      // the value exactly where the animation had reached, so a pause freezes
      // the orb mid-flight. iOS samples the breath curve by hand to find it.
      if (isPaused) {
        swell.stop()
      } else if (!currentReduceMotion && phase != Phase.Finished) {
        // Carries the orb the rest of the way, over the time the phase has left.
        val remaining = engine.remainingInPhase ?: engine.currentPhaseDuration
        scope.launch {
          swell.animateTo(if (phase == Phase.Inhale) 1f else 0f, breath(remaining.seconds()))
        }
      }
      announcement = resources.getString(cueText(phase, isPaused))
    }
  }

  /**
   * Mid-practice, leaving asks first and the breath freezes under the
   * question. The countdown and the finished settle dismiss directly.
   */
  fun requestClose() {
    if (countdown != null || engine.state.value.phase == Phase.Finished) {
      currentOnClose()
      return
    }
    wasPausedBeforeConfirm = engine.state.value.isPaused
    engine.pause()
    confirmingLeave = true
  }

  fun keepBreathing() {
    confirmingLeave = false
    if (!wasPausedBeforeConfirm) engine.togglePaused()
  }

  BackHandler(enabled = !confirmingLeave) { requestClose() }

  val controlHidden = countdown != null || state.phase == Phase.Finished

  Box(
    modifier
      .fillMaxSize()
      // Opaque under the atmosphere's translucent stops: the practice covers
      // the shell, and nothing beneath may show through.
      .background(Color.moonCream),
  ) {
    AtmosphereBackground()

    Column(
      Modifier
        .fillMaxSize()
        .safeDrawingPadding()
        .padding(horizontal = Dp.edge),
      horizontalAlignment = Alignment.CenterHorizontally,
    ) {
      Spacer(Modifier.weight(1f))

      BreathingOrb(
        swell = swell.value,
        glow = glow.value,
        modifier = Modifier.width(ORB_SIZE),
      )

      CueBlock(
        countdown = countdown,
        cue = cueLine,
        caption = caption,
        announcement = announcement,
        modifier = Modifier.padding(top = Dp.rhythm * 1.5f),
      )

      Spacer(Modifier.weight(1f))

      PlayPauseButton(
        isPaused = state.isPaused,
        hidden = controlHidden,
        onClick = { engine.togglePaused() },
        modifier = Modifier.padding(bottom = Dp.rhythm),
      )
    }

    HeaderIconButton(
      icon = GlobalPauseIcons.Close,
      contentDescription = stringResource(R.string.session_close),
      onClick = { requestClose() },
      modifier = Modifier
        .align(Alignment.TopStart)
        .safeDrawingPadding()
        .padding(Dp.edge),
    )
  }

  if (confirmingLeave) {
    DeepConfirmDialog(
      title = stringResource(R.string.session_leave_confirm),
      message = stringResource(R.string.session_leave_confirm_body),
      actions = listOf(
        DialogAction(label = stringResource(R.string.session_stay), onClick = { keepBreathing() }),
        DialogAction(
          label = stringResource(R.string.session_leave),
          destructive = true,
          onClick = {
            confirmingLeave = false
            currentOnClose()
          },
        ),
      ),
      // The scrim and back are the cancel, as on iOS: keep breathing.
      onDismissRequest = { keepBreathing() },
    )
  }
}

/** The cue line — the phase, or "Paused" while paused. */
private fun cueText(phase: Phase, isPaused: Boolean): Int = when {
  phase == Phase.Finished -> R.string.session_ending
  isPaused -> R.string.session_paused
  phase == Phase.Inhale -> R.string.session_breathe_in
  else -> R.string.session_breathe_out
}

/**
 * The line under the cue: how much is left, coarse on purpose. Recomputed at
 * each turn of the breath (the engine's state is observed) rather than on a
 * clock, so nothing new ticks on a screen meant to be watched with the eyes
 * half shut.
 */
@Composable
private fun captionText(state: BreathEngine.State, engine: BreathEngine): String = when {
  state.phase == Phase.Finished -> stringResource(R.string.session_complete)
  state.isPaused -> stringResource(R.string.session_take_your_time)
  else -> when (val left = SessionTimeLeft.of(engine.remainingInSession)) {
    SessionTimeLeft.AlmostThere -> stringResource(R.string.session_time_left_almost)
    SessionTimeLeft.AboutAMinute -> stringResource(R.string.session_time_left_minute)
    is SessionTimeLeft.AboutMinutes -> stringResource(R.string.session_time_left_minutes, left.minutes)
  }
}

/**
 * The settling count with "Settling in" beneath it, then the cue with the time
 * left. One polite live region carries [announcement] — iOS's announcements —
 * while the caption stays its own node, there to be read but never spoken
 * over the breath.
 */
@Composable
private fun CueBlock(
  countdown: Int?,
  cue: String,
  caption: String,
  announcement: String,
  modifier: Modifier = Modifier,
) {
  Column(
    modifier,
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(CUE_SPACING),
  ) {
    Box(
      Modifier.clearAndSetSemantics {
        contentDescription = announcement.ifEmpty { countdown?.toString() ?: cue }
        liveRegion = LiveRegionMode.Polite
      },
      contentAlignment = Alignment.Center,
    ) {
      AnimatedContent(
        targetState = countdown?.let { it.toString() to true } ?: (cue to false),
        transitionSpec = { fadeIn(bloom()) togetherWith fadeOut(bloom()) },
        label = "session-cue",
      ) { (line, isCount) ->
        Text(
          text = line,
          style = if (isCount) DeepType.bigNumber else DeepType.displayTitle,
          color = Color.deepPlum,
          textAlign = TextAlign.Center,
        )
      }
    }

    val captionLine = if (countdown != null) stringResource(R.string.session_settling_in) else caption
    AnimatedContent(
      targetState = captionLine,
      transitionSpec = { fadeIn(bloom()) togetherWith fadeOut(bloom()) },
      label = "session-caption",
    ) { line ->
      Text(
        text = line,
        style = DeepType.caption,
        color = Color.driftGrey,
        textAlign = TextAlign.Center,
      )
    }
  }
}

/**
 * The one control: a 64dp gradient circle carrying play or pause, lifted on
 * the lavender bloom the app's key actions share. It fades away while the
 * settling count runs and once the practice has finished — and leaves the
 * accessibility tree and the hit test with it.
 */
@Composable
private fun PlayPauseButton(
  isPaused: Boolean,
  hidden: Boolean,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val presence by animateFloatAsState(
    targetValue = if (hidden) 0f else 1f,
    animationSpec = bloom(),
    label = "session-control",
  )
  val label = stringResource(if (isPaused) R.string.session_resume else R.string.session_pause)

  Box(
    modifier
      // ModulateAlpha, not an offscreen layer: a layer is clipped to the
      // circle's bounds, which would cut the bloom into a hard square.
      .graphicsLayer {
        alpha = presence
        compositingStrategy = CompositingStrategy.ModulateAlpha
      }
      .then(if (hidden) Modifier.semantics { hideFromAccessibility() } else Modifier)
      .size(CONTROL_SIZE)
      .softPress()
      .dropShadow(
        shape = CircleShape,
        shadow = Shadow(
          radius = BLOOM_RADIUS,
          color = Color.lavenderMist.copy(alpha = BLOOM_ALPHA),
          offset = DpOffset(0.dp, BLOOM_OFFSET_Y),
        ),
      )
      .background(Brush.linearGradient(listOf(Color.lavenderMist, Color.softLilac)), CircleShape)
      .clickable(
        enabled = !hidden,
        onClickLabel = label,
        role = Role.Button,
        interactionSource = null,
        indication = null,
        onClick = onClick,
      ),
    contentAlignment = Alignment.Center,
  ) {
    Icon(
      imageVector = if (isPaused) PlayerIcons.Play else PlayerIcons.Pause,
      contentDescription = label,
      tint = Color.White,
      modifier = Modifier.size(CONTROL_GLYPH),
    )
  }
}

private fun Duration.seconds(): Float = toDouble(DurationUnit.SECONDS).toFloat()

/** iOS's `.frame(width: 280)`. */
private val ORB_SIZE = 280.dp
private val CUE_SPACING = 8.dp

/** iOS's 64pt play / pause circle and its 22pt glyph. */
private val CONTROL_SIZE = 64.dp
private val CONTROL_GLYPH = 26.dp

/** The bloom beneath the control — iOS's `shadow(lavenderMist 0.4, radius: 12, y: 6)`. */
private const val BLOOM_ALPHA = 0.4f
private val BLOOM_RADIUS = 12.dp
private val BLOOM_OFFSET_Y = 6.dp

/** Where the orb gathers to during the settling count. */
private const val GATHERED_SWELL = 0.25f

/** Where the orb settles once the last exhale lands. */
private const val FINISHED_SWELL = 0.6f

/** Under reduced motion the orb holds this size and breathes as light. */
private const val REDUCED_SWELL = 0.6f
private const val REDUCED_GLOW_REST = 0.7f
private const val REDUCED_GLOW_GATHERED = 0.85f

@Preview(showBackground = true, name = "Mid-inhale")
@Composable
private fun DeepSessionScreenPreview() {
  val scope = rememberCoroutineScope()
  DeepTheme {
    DeepSessionScreen(
      engine = remember {
        BreathEngine(
          DeepSession(id = "preview", title = "Balancing breath", tagline = "", cycles = 6),
          scope,
        )
      },
      onClose = {},
      countdownSeconds = 0,
    )
  }
}

@Preview(showBackground = true, name = "Settling in")
@Composable
private fun DeepSessionScreenCountdownPreview() {
  val scope = rememberCoroutineScope()
  DeepTheme {
    DeepSessionScreen(
      engine = remember {
        BreathEngine(DeepSession(id = "preview", title = "", tagline = "", cycles = 6), scope)
      },
      onClose = {},
    )
  }
}
