package io.appbeyond.freelance.deep.shared.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.exhaleEasing
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.peachCloud
import io.appbeyond.freelance.deep.theme.skyWash
import io.appbeyond.freelance.deep.theme.softLilac
import kotlinx.coroutines.isActive

/**
 * One ambient orb's spec.
 *
 * Hoisted out of the composable because the launch screen ships this same
 * atmosphere as a flat still — a launch window runs no code — and that still has
 * to land on the resting offsets, or the hand-off from the splash into Compose
 * shows a jump. One declaration, two consumers.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Components/AtmosphereBackground.swift.
 */
data class Orb(
  val color: Color,
  val size: Dp,
  /** The gaussian radius the iOS orb is blurred by. Here it sets the falloff. */
  val blur: Dp,
  /** Where the orb sits at rest — the app's first frame, and so the splash's. */
  val restX: Dp,
  val restY: Dp,
  /** The far end of the ambient drift. */
  val driftedX: Dp,
  val driftedY: Dp,
)

/** Back to front — the list's order is the draw order. */
val atmosphereOrbs: List<Orb> = listOf(
  Orb(Color.lavenderMist, 220.dp, 60.dp, (-120).dp, (-240).dp, (-90).dp, (-260).dp),
  Orb(Color.blushPowder, 180.dp, 70.dp, 110.dp, (-210).dp, 130.dp, (-180).dp),
  Orb(Color.skyWash, 160.dp, 60.dp, (-100).dp, 300.dp, (-120).dp, 320.dp),
)

/**
 * The sky wash. Its lower stops are translucent by design — the atmosphere is
 * always composited over moonCream, so anything that flattens this gradient has
 * to lay it over moonCream first.
 */
private val skyStops = listOf(
  0.00f to Color.moonCream,
  0.38f to Color.softLilac.copy(alpha = 0.55f),
  0.72f to Color.blushPowder.copy(alpha = 0.45f),
  1.00f to Color.peachCloud.copy(alpha = 0.30f),
)

/** The alpha an orb's core carries before its falloff begins. */
private const val ORB_CORE_ALPHA = 0.55f

/** How long one leg of the ambient drift takes. */
private const val DRIFT_MILLIS = 14_000

/** How long the drift takes to ease back to rest when it is told to hold still. */
private const val SETTLE_MILLIS = 2_000

/**
 * The signature backdrop: a vertical sky wash with three soft orbs drifting
 * across it.
 *
 * **The orbs are radial gradients, not blurred circles.** `Modifier.blur` is a
 * no-op below API 31 and the floor here is 26, so a blurred circle would simply
 * render as a hard disc on older devices — the exact failure the iOS side guards
 * against by keeping its blurred orbs off any rasterising layer. A radial
 * gradient with a gaussian-ish falloff *is* a blurred circle by construction,
 * costs a fraction of a real blur pass, and looks identical at every API level.
 *
 * @param animated set false where the atmosphere must hold still. The drift
 *   settles back to rest rather than stopping where it stands.
 */
@Composable
fun AtmosphereBackground(
  modifier: Modifier = Modifier,
  animated: Boolean = true,
) {
  val reduceMotion = rememberReduceMotion()
  val drift = remember { Animatable(0f) }

  // An Animatable driven by hand rather than rememberInfiniteTransition, for two
  // reasons. An infinite transition cannot *settle* — asked to stop it would halt
  // wherever it stood, where this has to ease back to rest so the orbs land on
  // the offsets the splash ships as a still. And an infinite transition keeps
  // running a frame loop even when its target equals its start, which would leave
  // the resting atmosphere behind the whole app invalidating every frame forever.
  //
  // Stopping when still means the resting orbs genuinely cost nothing per frame,
  // which is what the iOS comment claims and this now matches.
  LaunchedEffect(animated, reduceMotion) {
    if (animated && !reduceMotion) {
      while (isActive) {
        drift.animateTo(1f, tween(DRIFT_MILLIS, easing = exhaleEasing))
        drift.animateTo(0f, tween(DRIFT_MILLIS, easing = exhaleEasing))
      }
    } else {
      drift.animateTo(0f, tween(SETTLE_MILLIS, easing = exhaleEasing))
    }
  }

  val density = LocalDensity.current

  Box(modifier = modifier.fillMaxSize()) {
    Canvas(Modifier.fillMaxSize()) {
      drawRect(
        brush = Brush.verticalGradient(
          colorStops = skyStops.toTypedArray(),
          startY = 0f,
          endY = size.height,
        )
      )

      val centre = Offset(size.width / 2f, size.height / 2f)

      atmosphereOrbs.forEach { orb ->
        with(density) {
          val x = lerp(orb.restX.toPx(), orb.driftedX.toPx(), drift.value)
          val y = lerp(orb.restY.toPx(), orb.driftedY.toPx(), drift.value)

          // A gaussian-blurred disc spreads much further than its own radius and
          // has almost no flat core. Taking sigma as roughly two thirds of the
          // blur radius, the light is spent by three sigma — so the gradient runs
          // to the disc's radius plus twice the blur, and the stops trace the
          // error-function profile rather than a plateau with a skirt.
          //
          // Getting this wrong is visible: too tight a radius or too strong a
          // core and the orbs read as defined circles, which is the opposite of
          // the "dust in a sunbeam" DESIGN.md asks for.
          val coreRadius = orb.size.toPx() / 2f
          val radius = coreRadius + orb.blur.toPx() * 2f
          val edge = (coreRadius / radius).coerceIn(0.05f, 0.95f)
          val skirt = 1f - edge

          drawCircle(
            brush = Brush.radialGradient(
              colorStops = arrayOf(
                0f to orb.color.copy(alpha = ORB_CORE_ALPHA),
                edge * 0.45f to orb.color.copy(alpha = ORB_CORE_ALPHA * 0.86f),
                edge * 0.8f to orb.color.copy(alpha = ORB_CORE_ALPHA * 0.66f),
                // A gaussian sits at half its peak on the original edge.
                edge to orb.color.copy(alpha = ORB_CORE_ALPHA * 0.5f),
                edge + skirt * 0.33f to orb.color.copy(alpha = ORB_CORE_ALPHA * 0.18f),
                edge + skirt * 0.66f to orb.color.copy(alpha = ORB_CORE_ALPHA * 0.04f),
                1f to orb.color.copy(alpha = 0f),
              ),
              center = centre + Offset(x, y),
              radius = radius,
            ),
            radius = radius,
            center = centre + Offset(x, y),
          )
        }
      }
    }
  }
}

private fun lerp(from: Float, to: Float, fraction: Float): Float =
  from + (to - from) * fraction

@Preview(showBackground = true)
@Composable
private fun AtmosphereBackgroundPreview() {
  AtmosphereBackground()
}

@Preview(showBackground = true, name = "Static")
@Composable
private fun AtmosphereBackgroundStaticPreview() {
  AtmosphereBackground(animated = false)
}
