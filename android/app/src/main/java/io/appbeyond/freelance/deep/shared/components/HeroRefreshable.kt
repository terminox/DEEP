package io.appbeyond.freelance.deep.shared.components

import android.os.SystemClock
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.shared.refresh.RefreshCueMachine
import io.appbeyond.freelance.deep.shared.refresh.RefreshCuePhase
import io.appbeyond.freelance.deep.shared.refresh.RefreshCueState
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.peachCloud
import io.appbeyond.freelance.deep.theme.settle
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.min

// MARK: - Constants

/** The cue's glass disc — iOS's 44pt frame. */
private val CUE_SIZE = 44.dp

/** The progress ring and spinner inside it — iOS's 20pt frame. */
private val RING_SIZE = 20.dp

/** Ring stroke — iOS's `lineWidth: 2.5`. */
private val RING_WIDTH = 2.5.dp

/**
 * Distance below the safe-area top that clears the pinned title block — the
 * [CollapsibleHomeHeader] large title starts 6dp below it and its subtitle
 * caption ends near 56dp — so the cue always parks below the title and
 * subtitle, never over them. iOS's `headerClearance`.
 */
private val HEADER_CLEARANCE = 64.dp

/** How far the cue drifts down with the pull, as a share of it. */
private const val FOLLOW_RATIO = 0.15f

/** The cue materialises from this scale as the pull arms it. */
private const val ENTRY_SCALE = 0.8f

/** The spinner's arc, as a share of a full turn. */
private const val SPINNER_SWEEP_DEGREES = 100f

/**
 * One turn of the hand-drawn spinner. iOS leaves this to the system `ProgressView`, whose
 * timing isn't exposed to cite; no theme curve (`hush`/`exhale`/`bloom`/`ripple`) matches this
 * duration either, so it's a local value tuned to read like a system spinner.
 */
private const val SPIN_MILLIS = 900

/**
 * Under reduced motion the arc holds still and breathes its opacity instead, over one slow
 * half-breath each way — same story as [SPIN_MILLIS]: no iOS or theme value to cite.
 */
private const val STILL_BREATH_MILLIS = 1_200
private const val STILL_BREATH_FLOOR = 0.35f

// MARK: - Container

/**
 * Pull-to-refresh for hero-led screens. A full-bleed [StretchyHero] stays
 * pinned over the exact spot a stock refresh spinner would live, and the stock
 * trigger sits deeper than this app wants — so this replaces
 * `PullToRefreshBox` outright: it watches the hero's own pull, arms a small
 * frosted [RefreshCue] just below the pinned title block, and fires the moment
 * the pull crosses the threshold while the finger is still down — no deep
 * drag, no release required, and never on a fling that bounces off the top.
 *
 * Ported from Deep/Deep/Shared/Components/RefreshCue.swift (`heroRefreshable`).
 * The state machine — the 52dp trigger, 14dp dead zone, 10dp re-arm latch and
 * the 600ms spinner floor — is [RefreshCueMachine] in :core:model; this is the
 * Compose driver around it.
 *
 * **Why a container rather than a modifier.** The cue is composable content
 * (a frosted disc, a crossfading ring), and a modifier cannot host a
 * composable. Wrap the whole screen:
 *
 * ```
 * val (pull, nestedScroll) = rememberHeroPull(listState)
 * HeroRefreshable(pull = pull, onRefresh = { reload() }) {
 *   CollapsibleHomeHeader(title = …, listState = listState) {
 *     LazyColumn(state = listState, modifier = Modifier.nestedScroll(nestedScroll)) { … }
 *   }
 * }
 * ```
 *
 * **It rides the hero's pull rather than measuring its own.** Compose reports
 * no overscroll offset — [rememberHeroPull]'s nested-scroll connection is
 * already the one place the rubber-band distance exists, and only drags feed
 * it. Reading that same [HeroPull] keeps the stretch and the cue on one
 * number. The finger is tracked separately, on the initial pointer pass
 * without consuming anything, because SwiftUI's `.interacting` phase has no
 * Compose twin.
 *
 * A light haptic lands as it fires, and TalkBack gets a "Refresh" custom
 * action on this container, since a screen reader cannot rubber-band.
 *
 * @param pull the hero's overscroll, from [rememberHeroPull].
 * @param onRefresh the reload. The cue spins until it returns, and for at least
 *   600ms. It must handle its own failures — an exception thrown here ends the
 *   refresh and then propagates, exactly like any other coroutine.
 * @param content the screen. Keep the header inside it, so the cue draws over
 *   the header rather than beneath it.
 */
@Composable
fun HeroRefreshable(
  pull: HeroPull,
  onRefresh: suspend () -> Unit,
  modifier: Modifier = Modifier,
  content: @Composable () -> Unit,
) {
  val density = LocalDensity.current
  val haptics = LocalHapticFeedback.current
  val scope = rememberCoroutineScope()
  val currentOnRefresh by rememberUpdatedState(onRefresh)
  val currentPull = rememberUpdatedState(pull.value / density.density)

  val monitor = remember(scope) {
    RefreshMonitor(
      scope = scope,
      onFire = { haptics.performHapticFeedback(HapticFeedbackType.GestureThresholdActivate) },
      action = { currentOnRefresh() },
    )
  }

  // The trigger is re-evaluated whenever either input moves: a pull held
  // perfectly still produces no new distance, and the finger lifting must
  // latch the re-arm even when the stretch has already settled.
  LaunchedEffect(monitor) {
    snapshotFlow { currentPull.value to monitor.isDragging }
      .collect { (distance, dragging) -> monitor.update(distance, dragging) }
  }

  val refreshLabel = stringResource(R.string.refresh_action)

  Box(
    modifier
      .pointerInput(monitor) {
        awaitEachGesture {
          awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
          monitor.isDragging = true
          try {
            do {
              val event = awaitPointerEvent(PointerEventPass.Initial)
            } while (event.changes.any { it.pressed })
          } finally {
            monitor.isDragging = false
          }
        }
      }
      .semantics {
        customActions = listOf(
          CustomAccessibilityAction(refreshLabel) {
            monitor.beginRefresh()
            true
          },
        )
      },
  ) {
    content()
    RefreshCueHost(monitor, Modifier.align(Alignment.TopCenter))
  }
}

// MARK: - Monitor

/**
 * The Compose driver for [RefreshCueMachine]: owns the snapshot state the cue
 * reads, and the coroutine that runs the refresh and holds the spinner floor.
 *
 * Read only by [RefreshCueHost], never by [HeroRefreshable]'s own body, so the
 * per-frame pull writes during a drag invalidate nothing but the small cue.
 */
@Stable
private class RefreshMonitor(
  private val scope: CoroutineScope,
  private val onFire: () -> Unit,
  private val action: suspend () -> Unit,
) {
  var state by mutableStateOf(RefreshCueState())
    private set

  var isDragging by mutableStateOf(false)

  fun update(distance: Float, dragging: Boolean) {
    reduce(RefreshCueMachine.pull(state, distance, dragging, now()))
  }

  /** The TalkBack entry point — starts a refresh without the gesture gates. */
  fun beginRefresh() {
    reduce(RefreshCueMachine.beginRefresh(state, now()))
  }

  private fun reduce(next: RefreshCueState) {
    val fired = state.phase == RefreshCuePhase.Idle && next.phase == RefreshCuePhase.Refreshing
    state = next
    if (fired) start()
  }

  private fun start() {
    onFire()
    scope.launch {
      try {
        action()
      } finally {
        // Runs even if the reload is cancelled mid-flight, so the cue can
        // never wedge spinning. The machine refuses to finish before the
        // floor, so wait out whatever is left of it first.
        withContext(NonCancellable) {
          while (state.phase == RefreshCuePhase.Refreshing) {
            val remaining = RefreshCueMachine.MIN_SPINNER_MILLIS - (now() - state.refreshStartedAtMillis)
            if (remaining > 0) delay(remaining)
            state = RefreshCueMachine.refreshFinished(state, now())
          }
        }
      }
    }
  }

  private fun now(): Long = SystemClock.uptimeMillis()
}

// MARK: - Cue host

/**
 * Parks the cue [HEADER_CLEARANCE] below the status bar, materialising it from
 * the dead zone and letting it drift gently with the pull. It tracks the finger
 * with no animation of its own; only its arrival and departure are sprung.
 */
@Composable
private fun RefreshCueHost(monitor: RefreshMonitor, modifier: Modifier = Modifier) {
  val state = monitor.state
  val visible = RefreshCueMachine.isVisible(state)

  AnimatedVisibility(
    visible = visible,
    enter = fadeIn(settle()) + scaleIn(settle(), initialScale = ENTRY_SCALE),
    exit = fadeOut(settle()) + scaleOut(settle(), targetScale = ENTRY_SCALE),
    modifier = modifier
      .windowInsetsPadding(WindowInsets.statusBars)
      .padding(top = HEADER_CLEARANCE),
  ) {
    RefreshCue(
      progress = RefreshCueMachine.pullProgress(state),
      isSpinning = RefreshCueMachine.isSpinning(state),
      modifier = Modifier.graphicsLayer {
        val current = monitor.state
        alpha = RefreshCueMachine.opacity(current)
        val scale = RefreshCueMachine.scale(current)
        scaleX = scale
        scaleY = scale
        translationY = (min(current.pull, RefreshCueMachine.THRESHOLD) * FOLLOW_RATIO).dp.toPx()
      },
    )
  }
}

// MARK: - Cue

/**
 * The refresh cue itself: a small frosted disc holding a progress ring while
 * the pull is armed, crossfading to a spinner once the refresh fires.
 *
 * iOS draws the disc in Liquid Glass; here it is the app's [frostedCard]
 * surface rounded into a circle — the same frosted family every card on the
 * home already wears. The ring and spinner are deepPlum, as on iOS, and drawn
 * by hand: hero screens hide Material's indicator, and a stock one would bring
 * Material's motion with it.
 *
 * @param progress 0…1 fill of the ring while the pull is armed.
 * @param isSpinning swaps the ring for the spinner once the refresh fires.
 */
@Composable
fun RefreshCue(
  progress: Float,
  isSpinning: Boolean,
  modifier: Modifier = Modifier,
) {
  val label = stringResource(R.string.refresh_in_progress)

  Box(
    modifier
      .size(CUE_SIZE)
      .frostedCard(cornerRadius = CUE_SIZE / 2)
      .semantics { contentDescription = label },
    contentAlignment = Alignment.Center,
  ) {
    Crossfade(targetState = isSpinning, animationSpec = settle(), label = "refresh-cue") { spinning ->
      if (spinning) Spinner() else ProgressRing(progress)
    }
  }
}

/** The armed ring, filling clockwise from twelve o'clock. */
@Composable
private fun ProgressRing(progress: Float) {
  Canvas(Modifier.size(RING_SIZE)) {
    val stroke = RING_WIDTH.toPx()
    drawArc(
      color = Color.deepPlum,
      startAngle = -90f,
      sweepAngle = 360f * progress.coerceIn(0f, 1f),
      useCenter = false,
      topLeft = Offset(stroke / 2f, stroke / 2f),
      size = Size(size.width - stroke, size.height - stroke),
      style = Stroke(width = stroke, cap = StrokeCap.Round),
    )
  }
}

/**
 * The indeterminate spinner — an arc turning at an even pace. Under reduced
 * motion the arc holds still and breathes its opacity instead.
 */
@Composable
private fun Spinner() {
  val reduceMotion = rememberReduceMotion()
  val transition = rememberInfiniteTransition(label = "refresh-spinner")
  val turn by transition.animateFloat(
    initialValue = 0f,
    targetValue = if (reduceMotion) 0f else 360f,
    animationSpec = infiniteRepeatable(tween(SPIN_MILLIS, easing = LinearEasing)),
    label = "refresh-spinner-turn",
  )
  val breath by transition.animateFloat(
    initialValue = 1f,
    targetValue = if (reduceMotion) STILL_BREATH_FLOOR else 1f,
    animationSpec = infiniteRepeatable(tween(STILL_BREATH_MILLIS), RepeatMode.Reverse),
    label = "refresh-spinner-breath",
  )

  Canvas(
    Modifier
      .size(RING_SIZE)
      .graphicsLayer {
        rotationZ = turn
        alpha = breath
      },
  ) {
    val stroke = RING_WIDTH.toPx()
    drawArc(
      color = Color.deepPlum,
      startAngle = -90f,
      sweepAngle = SPINNER_SWEEP_DEGREES,
      useCenter = false,
      topLeft = Offset(stroke / 2f, stroke / 2f),
      size = Size(size.width - stroke, size.height - stroke),
      style = Stroke(width = stroke, cap = StrokeCap.Round),
    )
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Refresh cue — mid-pull")
@Composable
private fun RefreshCueMidPullPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream), contentAlignment = Alignment.Center) {
      AtmosphereBackground()
      RefreshCue(progress = 0.6f, isSpinning = false)
    }
  }
}

@Preview(showBackground = true, name = "Refresh cue — spinning")
@Composable
private fun RefreshCueSpinningPreview() {
  DeepTheme {
    Box(
      Modifier
        .fillMaxSize()
        .background(Color.moonCream)
        .background(Brush.linearGradient(listOf(Color.peachCloud, Color.blushPowder, Color.lavenderMist))),
      contentAlignment = Alignment.Center,
    ) {
      RefreshCue(progress = 1f, isSpinning = true)
    }
  }
}

/** The whole stack on a hermetic screen: the reload is a fake one-second wait. */
@Preview(showBackground = true, name = "Hero refreshable — home shape")
@Composable
private fun HeroRefreshablePreview() {
  val listState = rememberLazyListState()
  val (pull, nestedScroll) = rememberHeroPull(listState)

  HeroRefreshable(pull = pull, onRefresh = { delay(PREVIEW_RELOAD_MILLIS) }) {
    CollapsibleHomeHeaderPreviewScreen(listState, pull, nestedScroll)
  }
}

private const val PREVIEW_RELOAD_MILLIS = 1_000L
