package io.appbeyond.freelance.deep.shared.components

import android.graphics.BlurMaskFilter
import android.graphics.LinearGradient
import android.graphics.Shader
import android.os.Build
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toAndroidRectF
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.peachCloud
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.skyWash
import io.appbeyond.freelance.deep.theme.softLilac
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

// MARK: - Constants

/** The faint ring the arcs ride on — iOS's `lavenderMist.opacity(0.16)`. */
private const val TRACK_ALPHA = 0.16f

/** The bloom's blur, as a fraction of the stroke width — iOS's `blur(radius: lineWidth * 0.6)`. */
private const val BLOOM_BLUR_FRACTION = 0.6f

/** The bloom's opacity — iOS's `.opacity(0.5)`. */
private const val BLOOM_ALPHA = 0.5f

/** One full turn, for converting shares of the circle to sweep angles. */
private const val FULL_TURN_DEGREES = 360f

/** Arcs start at twelve o'clock, as iOS's `rotationEffect(.degrees(-90))` does. */
private const val TWELVE_O_CLOCK = -90f

/** A framework paint's full alpha. */
private const val MAX_CHANNEL = 255f

// MARK: - Model

/**
 * One arc of a [CompassionRing].
 *
 * @property share how much of the whole circle this arc covers, `0..1`.
 *   Absolute, not normalised — an allocation ring passes shares that sum to 1,
 *   a progress ring passes a single arc of `progress`.
 * @property colors the arc's gradient stops — a cause's palette, so an arc and
 *   its motif read as the same thing.
 */
@Immutable
data class RingSegment(
  val share: Float,
  val colors: List<Color>,
)

// MARK: - Ring

/**
 * The portfolio's signature form: soft gradient arcs riding a faint ring, with
 * a blurred copy of themselves glowing beneath — the halo language DESIGN.md
 * asks for, and the reason no bars or rules are needed to show a proportion.
 * Serves the "where hearts go" allocation halo, a single project's progress,
 * and (through [PlantGrowthHalo]) the Mind Garden's growth ring.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/CompassionRing.swift.
 * iOS leaves the centre to a caller's `ZStack`; here it is the [content] slot.
 * The ring itself is hidden from accessibility — the caller owns the
 * description, and anything in [content] keeps its own semantics.
 *
 * The bloom is a `BlurMaskFilter` on the arc's paint rather than
 * `Modifier.blur`, which is a no-op below API 31. The mask filter is a real
 * gaussian on a hardware canvas from API 28; on 26–27 the bloom is skipped
 * (it would draw sharp, hidden exactly beneath the arc anyway).
 *
 * @param lineWidth the stroke width of the track and the arcs.
 * @param gap angular breathing room between arcs, as a fraction of the circle —
 *   the gap you actually see, after the round caps (see [drawRingArcs]). A
 *   single progress arc passes `0`.
 * @param trackColor the faint full circle the arcs ride on.
 * @param glowColor an optional soft glow under the sharp arcs (the growth
 *   halo's "fully grown" glow); transparent draws none.
 * @param glowRadius the glow's blur radius.
 * @param content composed at the ring's centre.
 */
@Composable
fun CompassionRing(
  segments: List<RingSegment>,
  modifier: Modifier = Modifier,
  lineWidth: Dp = 12.dp,
  gap: Float = 0.016f,
  trackColor: Color = Color.lavenderMist.copy(alpha = TRACK_ALPHA),
  glowColor: Color = Color.Transparent,
  glowRadius: Dp = 6.dp,
  content: @Composable BoxScope.() -> Unit = {},
) {
  // iOS animates the whole segment array with `.exhale`; each share eases on
  // its own here, keyed by position, which is the same thing for a stable count.
  val shares = segments.mapIndexed { index, segment ->
    key(index) {
      animateFloatAsState(
        targetValue = segment.share,
        animationSpec = exhale(),
        label = "ring-share",
      ).value
    }
  }

  Box(modifier, contentAlignment = Alignment.Center) {
    Canvas(Modifier.matchParentSize().clearAndSetSemantics {}) {
      val stroke = lineWidth.toPx()
      val radius = min(size.width, size.height) / 2f - stroke / 2f
      if (radius <= 0f) return@Canvas

      drawCircle(color = trackColor, radius = radius, style = Stroke(width = stroke))

      // The bloom: the same arcs, blurred and dimmed, so the ring glows into the
      // card rather than sitting on it.
      drawRingArcs(segments, shares, radius, stroke, gap, blurRadius = stroke * BLOOM_BLUR_FRACTION, alpha = BLOOM_ALPHA)

      if (glowColor.alpha > 0f) {
        drawRingArcs(segments, shares, radius, stroke, gap, blurRadius = glowRadius.toPx(), tint = glowColor)
      }

      drawRingArcs(segments, shares, radius, stroke, gap)
    }
    content()
  }
}

/**
 * Draws every arc, clockwise from twelve o'clock, each with its gradient
 * resolved across the whole ring's box — as iOS strokes a full-size `Circle`
 * trimmed to the arc, then rotates the lot by −90°, gradient included.
 *
 * A round cap overhangs the trimmed end by half the stroke width, so a gap
 * trimmed out of the path is partly drawn back in by the two caps facing
 * across it. At these proportions the caps swallow it whole — neighbouring
 * arcs touch, and five causes read as four. The overhang is measured against
 * the circumference and inset past, so `gap` means the gap that survives at
 * any size.
 *
 * @param blurRadius > 0 draws a gaussian-blurred copy (API 28+ only).
 * @param tint draws every arc in one flat colour instead of its gradient (the
 *   growth halo's glow).
 */
private fun DrawScope.drawRingArcs(
  segments: List<RingSegment>,
  shares: List<Float>,
  radius: Float,
  stroke: Float,
  gap: Float,
  blurRadius: Float = 0f,
  alpha: Float = 1f,
  tint: Color? = null,
) {
  if (blurRadius > 0f && Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return

  val capBleed = (stroke / 2f) / (2f * PI.toFloat() * radius)
  val inset = if (segments.size > 1) gap / 2f + capBleed else 0f
  val ringBox = Rect(center = center, radius = radius)

  rotate(TWELVE_O_CLOCK) {
    var start = 0f
    segments.forEachIndexed { index, segment ->
      val share = shares.getOrElse(index) { segment.share }
      val from = start + inset
      val to = max(from, start + share - inset)
      start += share
      if (to <= from) return@forEachIndexed

      // A framework paint, because the bloom needs its mask filter.
      val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
        style = android.graphics.Paint.Style.STROKE
        strokeWidth = stroke
        strokeCap = android.graphics.Paint.Cap.ROUND
        if (tint != null) {
          color = tint.toArgb()
        } else {
          // A gradient needs two stops; a one-colour arc is that colour twice.
          val stops = when (segment.colors.size) {
            0 -> listOf(Color.Transparent, Color.Transparent)
            1 -> segment.colors + segment.colors
            else -> segment.colors
          }
          shader = LinearGradient(
            ringBox.left,
            ringBox.top,
            ringBox.right,
            ringBox.bottom,
            stops.map { it.toArgb() }.toIntArray(),
            null,
            Shader.TileMode.CLAMP,
          )
          this.alpha = (alpha * MAX_CHANNEL).roundToInt()
        }
        if (blurRadius > 0f) {
          maskFilter = BlurMaskFilter(blurRadius, BlurMaskFilter.Blur.NORMAL)
        }
      }

      drawContext.canvas.nativeCanvas.drawArc(
        ringBox.toAndroidRectF(),
        from * FULL_TURN_DEGREES,
        (to - from) * FULL_TURN_DEGREES,
        false,
        paint,
      )
    }
  }
}

// MARK: - Previews

/** Preview stand-ins for five causes' single-hue palettes. */
private val PreviewAllocation = listOf(
  RingSegment(0.32f, listOf(Color.softLilac, Color.lavenderMist)),
  RingSegment(0.24f, listOf(Color.blushPowder, Color.blushPowder.copy(alpha = 0.8f))),
  RingSegment(0.18f, listOf(Color.skyWash, Color.softLilac)),
  RingSegment(0.16f, listOf(Color.peachCloud, Color.blushPowder)),
  RingSegment(0.10f, listOf(Color.lavenderMist, Color.deepPlum.copy(alpha = 0.5f))),
)

@Preview(showBackground = true, name = "Allocation halo")
@Composable
private fun CompassionRingPreview() {
  Box(Modifier.fillMaxSize().background(Color.moonCream)) {
    AtmosphereBackground(animated = false)
    Column(
      modifier = Modifier.padding(Dp.edge),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
      horizontalAlignment = Alignment.CenterHorizontally,
    ) {
      CompassionRing(segments = PreviewAllocation, lineWidth = 14.dp, modifier = Modifier.size(140.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
          Text("73K", style = DeepType.counter, color = Color.deepPlum)
          Text("POOLED", style = DeepType.micro, color = Color.driftGrey)
        }
      }

      // A single progress arc — the same primitive, one segment, no gap.
      CompassionRing(
        segments = listOf(RingSegment(0.62f, listOf(Color.blushPowder, Color.softLilac))),
        lineWidth = 5.dp,
        gap = 0f,
        modifier = Modifier.size(72.dp),
      ) {
        Text("62%", style = DeepType.micro, color = Color.deepPlum)
      }
    }
  }
}
