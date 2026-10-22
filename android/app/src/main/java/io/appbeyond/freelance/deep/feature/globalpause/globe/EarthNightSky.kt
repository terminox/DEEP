package io.appbeyond.freelance.deep.feature.globalpause.globe

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.tooling.preview.Preview
import io.appbeyond.freelance.deep.feature.globalpause.earth.NightSkyStar
import io.appbeyond.freelance.deep.feature.globalpause.earth.NightSkyStarField
import io.appbeyond.freelance.deep.feature.globalpause.earth.smoothstep
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.nightHorizon
import io.appbeyond.freelance.deep.theme.nightZenith
import io.appbeyond.freelance.deep.theme.skyWash
import io.appbeyond.freelance.deep.theme.softLilac
import kotlin.math.PI
import kotlin.math.sin

/**
 * The Global Pause night — iOS `NightSkyBackground` at its shipped
 * `NightSkyTuning` values: a plum sky darkening upward, a lilac glow at the
 * horizon, and a seeded field of stars, a share of them twinkling.
 *
 * Like the iOS card, the sky is drawn SCREEN-sized and anchored at the view's
 * top-left, the view being a window onto it: the lounge card shows the top of
 * the night, the session the whole of it. During the card lift the session's
 * sky anchors at the flight's corner instead ([GlobeFlight.skyAnchor]), so
 * the sky over the rising card is the card's own — no star jumps at lift-off.
 *
 * Twinkles at 30 fps; still under reduced motion, every twinkling star resting
 * at its mid brightness, as iOS.
 */
@Composable
internal fun EarthNightSky(flight: GlobeFlight?, modifier: Modifier = Modifier) {
  val reduceMotion = rememberReduceMotion()
  val stars = remember { NightSkyStarField.stars(SkyLook.SEED, SkyLook.STAR_COUNT).map(::PaintedStar) }
  val rootView = LocalView.current.rootView
  val bounds = remember { BoundsHolder() }

  var seconds by remember { mutableFloatStateOf(0f) }
  // The card's sky sleeps while the session covers it; the session's never.
  val sleeping = flight?.phase == GlobeFlight.Phase.Landed && !flight.isBackdrop(bounds.rect)
  LaunchedEffect(reduceMotion, sleeping) {
    if (reduceMotion || sleeping) return@LaunchedEffect
    var last = 0L
    while (true) {
      withFrameNanos { now ->
        if (now - last >= TWINKLE_FRAME_NANOS) {
          last = now
          // Wrapped daily so a float keeps sub-frame precision on long uptimes.
          seconds = ((now / 1_000_000_000.0) % 86_400.0).toFloat()
        }
      }
    }
  }

  Spacer(
    modifier
      .clipToBounds()
      .onGloballyPositioned { bounds.rect = it.unclippedRectInRoot() }
      .clearAndSetSemantics {}
      .drawWithCache {
        val sky = Size(
          rootView.width.takeIf { it > 0 }?.toFloat() ?: size.width,
          rootView.height.takeIf { it > 0 }?.toFloat() ?: size.height,
        )
        // Built once per size: per-frame twinkle only scales their alpha.
        val halos = stars.map { it.halo(sky, density) }
        onDrawBehind {
          val anchor = flight?.skyAnchor(bounds.rect) ?: Offset.Zero
          translate(anchor.x, anchor.y) {
            drawSky(sky)
            drawStars(sky, stars, halos, twinkleSeconds = if (reduceMotion) null else seconds)
          }
        }
      },
  )
}

/** Written on layout, read in draw — no recomposition per scroll frame. */
private class BoundsHolder {
  var rect: Rect? = null
}

/** A star with its tint resolved once. */
private class PaintedStar(val star: NightSkyStar) {
  val tint: Color = run {
    val cool = lerp(Color.skyWash, Color.lavenderMist, SkyLook.TINT_BALANCE)
    lerp(Color.moonCream, cool, star.tintT * SkyLook.TINT_SPREAD)
  }
  val twinkles: Boolean = star.twinkleT < SkyLook.TWINKLE_SHARE

  fun centre(sky: Size) = Offset(star.x * sky.width, star.y * sky.height)

  fun radius(density: Float) = (SkyLook.STAR_SIZE_MIN + (SkyLook.STAR_SIZE_MAX - SkyLook.STAR_SIZE_MIN) * star.sizeT) * density

  /** The soft glow around the star at its full halo alpha. */
  fun halo(sky: Size, density: Float): Brush = Brush.radialGradient(
    listOf(tint.copy(alpha = SkyLook.GLOW_ALPHA), Color.Transparent),
    center = centre(sky),
    radius = radius(density) * SkyLook.GLOW_SCALE,
  )
}

private fun DrawScope.drawSky(sky: Size) {
  drawRect(Brush.verticalGradient(listOf(Color.nightZenith, Color.nightHorizon), endY = sky.height), size = sky)
  // The lilac glow at the horizon: an ellipse centred below the bottom edge,
  // 0.8 of the sky's size in each axis (SwiftUI's EllipticalGradient).
  val centre = Offset(sky.width * 0.5f, sky.height * 1.1f)
  val rx = sky.width * 0.8f
  val ry = sky.height * 0.8f
  scale(scaleX = rx / ry, scaleY = 1f, pivot = centre) {
    drawCircle(
      Brush.radialGradient(
        listOf(Color.softLilac.copy(alpha = SkyLook.HORIZON_GLOW), Color.Transparent),
        center = centre,
        radius = ry,
      ),
      radius = ry,
      center = centre,
    )
  }
}

private fun DrawScope.drawStars(sky: Size, stars: List<PaintedStar>, halos: List<Brush>, twinkleSeconds: Float?) {
  for ((index, painted) in stars.withIndex()) {
    val star = painted.star
    val osc = if (twinkleSeconds != null && painted.twinkles) {
      val angle = twinkleSeconds * 2f * PI.toFloat() * SkyLook.TWINKLE_SPEED * star.rateJitter + star.phase
      1f - SkyLook.TWINKLE_DEPTH * (0.5f + 0.5f * sin(angle))
    } else {
      1f - (if (painted.twinkles) SkyLook.TWINKLE_DEPTH * 0.5f else 0f)
    }
    val fade = 1f - smoothstep(1f - SkyLook.HORIZON_FADE, 1f, star.y)
    val alpha = (SkyLook.BRIGHTNESS_MIN + (SkyLook.BRIGHTNESS_MAX - SkyLook.BRIGHTNESS_MIN) * star.brightT) * osc * fade
    if (alpha <= 0.004f) continue
    val centre = painted.centre(sky)
    val radius = painted.radius(density)
    drawCircle(halos[index], radius = radius * SkyLook.GLOW_SCALE, center = centre, alpha = alpha)
    drawCircle(painted.tint.copy(alpha = alpha), radius = radius, center = centre)
  }
}

/** iOS `NightSkyTuning.Values` defaults — the shipped sky. */
private object SkyLook {
  const val SEED = 1
  const val STAR_COUNT = 90
  const val HORIZON_GLOW = 0.22f
  const val STAR_SIZE_MIN = 0.5f
  const val STAR_SIZE_MAX = 1.8f
  const val BRIGHTNESS_MIN = 0.3f
  const val BRIGHTNESS_MAX = 1.0f
  const val TWINKLE_SPEED = 0.5f
  const val TWINKLE_DEPTH = 0.5f
  const val TWINKLE_SHARE = 0.6f
  const val TINT_SPREAD = 0.5f
  const val TINT_BALANCE = 0.4f
  const val GLOW_SCALE = 2.6f
  const val GLOW_ALPHA = 0.35f
  const val HORIZON_FADE = 0.35f
}

private const val TWINKLE_FRAME_NANOS = 33_000_000L

@Preview(name = "Night sky", widthDp = 360, heightDp = 640)
@Composable
private fun EarthNightSkyPreview() {
  EarthNightSky(flight = null, modifier = Modifier.fillMaxSize())
}
