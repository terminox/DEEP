package io.appbeyond.freelance.deep.feature.onboarding.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.irisDusk
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm

// MARK: - Proportions

/** Ring stroke as a fraction of the outer diameter — measured off the app icon. */
private const val STROKE_FRACTION = 0.02f

/** Centre dot diameter as a fraction of the outer diameter — measured off the app icon. */
private const val DOT_FRACTION = 0.13f

/** The tight bright halo — iOS's first `shadow(tint 0.9, radius: size * 0.05)`. */
private const val INNER_HALO_REACH = 0.05f
private const val INNER_HALO_ALPHA = 0.9f

/** The wide soft halo it blooms inside — iOS's `shadow(tint 0.5, radius: size * 0.16)`. */
private const val OUTER_HALO_REACH = 0.16f
private const val OUTER_HALO_ALPHA = 0.5f

/** The dot's own bloom — iOS blurs the dot by 45% of its diameter at 0.6 opacity. */
private const val DOT_BLOOM_REACH = 0.45f
private const val DOT_BLOOM_ALPHA = 0.6f

/** Rings stacked outward per halo, each wider and fainter, standing in for a gaussian. */
private const val HALO_STEPS = 8

/**
 * The Deep mark — a thin ring with a single dot resting at its centre, the
 * shape the app icon carries. Drawn rather than shipped as a raster so it
 * holds the palette and its glow on its own terms: a crisp ring seated inside
 * its own bloom, cream light over the welcome screen's sunrise.
 *
 * Ported from Deep/Deep/Features/Onboarding/Components/DeepLogoMark.swift.
 * Every measurement is a proportion of [size], so the mark can never drift
 * from the icon. iOS builds the halo from a blurred copy plus two stacked
 * shadows; `Modifier.blur` is a no-op below API 31 and a platform shadow is
 * grey, so the same falloff is drawn here as stacked, fading strokes — the
 * way `frostedCard` draws its bloom.
 *
 * @param tint the mark's colour. Cream reads as light over the sunrise.
 * @param isGlowing whether it carries its halo.
 */
@Composable
fun DeepLogoMark(
  modifier: Modifier = Modifier,
  size: Dp = 110.dp,
  tint: Color = Color.moonCream,
  isGlowing: Boolean = true,
) {
  Canvas(
    modifier
      .size(size)
      .clearAndSetSemantics {},
  ) {
    val diameter = this.size.minDimension
    val stroke = diameter * STROKE_FRACTION
    val ringRadius = diameter / 2f - stroke / 2f
    val dotRadius = diameter * DOT_FRACTION / 2f

    if (isGlowing) {
      drawHalo(ringRadius, stroke, diameter * OUTER_HALO_REACH, OUTER_HALO_ALPHA, tint)
      drawHalo(ringRadius, stroke, diameter * INNER_HALO_REACH, INNER_HALO_ALPHA, tint)

      val dotBloom = dotRadius + diameter * DOT_FRACTION * DOT_BLOOM_REACH
      drawCircle(
        brush = Brush.radialGradient(
          colorStops = arrayOf(
            0f to tint.copy(alpha = DOT_BLOOM_ALPHA),
            dotRadius / dotBloom to tint.copy(alpha = DOT_BLOOM_ALPHA),
            1f to tint.copy(alpha = 0f),
          ),
          center = center,
          radius = dotBloom,
        ),
        radius = dotBloom,
      )
    }

    drawCircle(color = tint, radius = ringRadius, style = Stroke(width = stroke))
    drawCircle(color = tint, radius = dotRadius)
  }
}

/** One halo: rings widening outward from the stroke by up to [reach], fading as they go. */
private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawHalo(
  ringRadius: Float,
  stroke: Float,
  reach: Float,
  alpha: Float,
  tint: Color,
) {
  for (step in HALO_STEPS downTo 1) {
    val t = step / HALO_STEPS.toFloat()
    val layerAlpha = alpha * (1f - t) * (1f - t) / 2f
    drawCircle(
      color = tint.copy(alpha = layerAlpha),
      radius = ringRadius,
      style = Stroke(width = stroke + reach * 2f * t),
    )
  }
}

@Preview(showBackground = true, name = "Deep mark — cream over sunrise, and flat")
@Composable
private fun DeepLogoMarkPreview() {
  OnboardingPreviewBackdrop {
    Column(
      modifier = Modifier.fillMaxSize(),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm, Alignment.CenterVertically),
      horizontalAlignment = Alignment.CenterHorizontally,
    ) {
      DeepLogoMark()
      DeepLogoMark(size = 64.dp)
      DeepTheme {
        Box(Modifier.background(Color.moonCream)) {
          DeepLogoMark(tint = Color.irisDusk, isGlowing = false)
        }
      }
    }
  }
}
