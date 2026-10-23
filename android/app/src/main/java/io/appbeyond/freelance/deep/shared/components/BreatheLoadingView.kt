package io.appbeyond.freelance.deep.shared.components

import android.content.ContentResolver
import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.breathEasing
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import kotlinx.coroutines.isActive

// MARK: - Constants

/** Milliseconds per half-breath (rise, then settle) — a 5s cadence either way. */
private const val HALF_CYCLE_MILLIS = 5_000L

/** The dimmed opacity the text rests at between breaths. */
private const val REST_OPACITY = 0.55f

/**
 * The exhale send-off's upward travel. Ported from `SoftDrift.drop` in
 * Deep/Deep/Shared/Transition/SoftDriftTransition.swift (16pt) — the same
 * magnitude `BreatheLoadingView.swift` draws by hand for its own send-off, so
 * this view keeps the same feel. It still draws the travel itself rather than
 * through `SoftDrift`, and the matching `SoftDrift.veil` blur (`Dp.veil`) is
 * left out: `Modifier.blur` is a no-op below API 31, and the send-off is a
 * single fade-and-rise that reads fine unblurred.
 */
private val EXHALE_DRIFT = 16.dp

private const val DEFAULT_LINE = "Take a deep breath.\nWe're preparing your space."

// MARK: - View

/**
 * DEEP's full-screen loading beat: an opaque, calm scene with a centred,
 * breathing line of serif text. Shown during whole-app waits — launch,
 * log-in, sign-up. Content-level waits use [SkeletonBlock] /
 * [SkeletonTextLine] instead.
 *
 * Ported from Deep/Deep/Shared/Components/BreatheLoadingView.swift. The
 * caller enforces `BREATHE_FLOOR_MILLIS` (the shortest a launch beat may stay
 * up) before dismissing this view — see `AppRoot.kt` — this composable only
 * owns the visual.
 *
 * @param drawsBackdrop set false where the host already keeps a persistent
 *   moonCream + [AtmosphereBackground] beneath this view, so only the
 *   breathing text renders. The host then owns the nothing-shows-through
 *   invariant.
 * @param exhaled flip to true to send the breathing line away: the breath
 *   freezes exactly where it stands (never snaps back to rest) and the now
 *   still text fades and drifts upward. A host that already wraps this view
 *   in its own exit animation (e.g. `AnimatedVisibility`) can leave this
 *   false and let that own the fade instead.
 */
@Composable
fun BreatheLoadingView(
  modifier: Modifier = Modifier,
  line: String = DEFAULT_LINE,
  drawsBackdrop: Boolean = true,
  exhaled: Boolean = false,
) {
  val reduceMotion = rememberReduceMotion()
  val paused = reduceMotion || exhaled
  val density = LocalDensity.current
  val exhaleDriftPx = with(density) { EXHALE_DRIFT.toPx() }

  // The breath itself, sampled from elapsed real time — not an
  // `infiniteRepeatable` animation — because the exhale must freeze the
  // breath exactly where it stands, not snap it back to rest, and an
  // `infiniteRepeatable` spec has no such pause. Mirrors iOS's
  // `TimelineView(.animation(paused:))` sampling by hand.
  var phase by remember { mutableFloatStateOf(0f) }
  LaunchedEffect(paused) {
    if (paused) return@LaunchedEffect
    val start = withFrameMillis { it }
    while (isActive) {
      val now = withFrameMillis { it }
      val cycle = (now - start) % (HALF_CYCLE_MILLIS * 2)
      phase = if (cycle < HALF_CYCLE_MILLIS) {
        cycle / HALF_CYCLE_MILLIS.toFloat()
      } else {
        2f - cycle / HALF_CYCLE_MILLIS.toFloat()
      }
    }
  }

  val breathOpacity = if (reduceMotion) {
    1f
  } else {
    REST_OPACITY + (1f - REST_OPACITY) * breathEasing.transform(phase)
  }

  // Same duration as a normal exhale under Reduce Motion too — "less motion,
  // not less time". Only the drift below is dropped in that case.
  val exhaleProgress by animateFloatAsState(
    targetValue = if (exhaled) 1f else 0f,
    animationSpec = exhale(),
    label = "breathe-loading-exhale",
  )

  Box(modifier.fillMaxSize()) {
    if (drawsBackdrop) {
      // Opaque base under the atmosphere's translucent stops: nothing beneath
      // this screen may ever show through.
      Box(Modifier.fillMaxSize().background(Color.moonCream))
      AtmosphereBackground()
    }

    Text(
      text = line,
      style = DeepType.displayTitle,
      color = Color.deepPlum,
      textAlign = TextAlign.Center,
      modifier = Modifier
        .align(Alignment.Center)
        .padding(horizontal = Dp.edge * 2)
        .semantics { liveRegion = LiveRegionMode.Polite }
        .graphicsLayer {
          alpha = breathOpacity * (1f - exhaleProgress)
          translationY = if (reduceMotion) 0f else -exhaleDriftPx * exhaleProgress
        },
    )
  }
}

// MARK: - Reduce motion

/**
 * Whether the system's animator duration scale is pinned to zero — the
 * signal Android exposes for "prefer reduced motion" (there is no dedicated
 * accessibility flag the way iOS has `accessibilityReduceMotion`). Both the
 * developer option and Accessibility's "Remove animations" set it. Several
 * components beyond this one need it, so it lives here rather than being
 * duplicated per call site.
 *
 * Observed live, as iOS's environment value is: the setting is changed from
 * the system's own settings while DEEP stays open in the background, and no
 * configuration change follows to recompose anything.
 */
@Composable
fun rememberReduceMotion(): Boolean {
  val resolver = LocalContext.current.contentResolver
  var reduceMotion by remember(resolver) { mutableStateOf(resolver.reducesMotion()) }
  val observes = !LocalInspectionMode.current
  DisposableEffect(resolver, observes) {
    if (!observes) return@DisposableEffect onDispose {}
    val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
      override fun onChange(selfChange: Boolean) {
        reduceMotion = resolver.reducesMotion()
      }
    }
    resolver.registerContentObserver(
      Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE),
      false,
      observer,
    )
    // Picks up a change made between the first read and registering.
    reduceMotion = resolver.reducesMotion()
    onDispose { resolver.unregisterContentObserver(observer) }
  }
  return reduceMotion
}

private fun ContentResolver.reducesMotion(): Boolean =
  Settings.Global.getFloat(this, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

// MARK: - Previews

@Preview(showBackground = true, name = "Breathe loading")
@Composable
private fun BreatheLoadingViewPreview() {
  BreatheLoadingView()
}

@Preview(showBackground = true, name = "Breathe loading — custom line")
@Composable
private fun BreatheLoadingViewCustomLinePreview() {
  BreatheLoadingView(line = "Almost there. Settle in.")
}

@Preview(showBackground = true, name = "Breathe loading — over host backdrop")
@Composable
private fun BreatheLoadingViewOverHostBackdropPreview() {
  Box(Modifier.fillMaxSize().background(Color.moonCream)) {
    AtmosphereBackground()
    BreatheLoadingView(drawsBackdrop = false)
  }
}

@Preview(showBackground = true, name = "Breathe loading — exhale")
@Composable
private fun BreatheLoadingViewExhalePreview() {
  var exhaled by remember { mutableStateOf(false) }

  Box(Modifier.fillMaxSize().background(Color.moonCream)) {
    AtmosphereBackground()
    BreatheLoadingView(drawsBackdrop = false, exhaled = exhaled)

    Box(Modifier.fillMaxSize().padding(bottom = Dp.rhythm), contentAlignment = Alignment.BottomCenter) {
      Button(onClick = { exhaled = !exhaled }) {
        Text(if (exhaled) "Breathe in" else "Exhale")
      }
    }
  }
}
