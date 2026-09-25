package io.appbeyond.freelance.deep.feature.onboarding.components

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Paint
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.irisDusk
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import kotlin.math.ceil
import android.graphics.Canvas as AndroidCanvas

// MARK: - Proportions

/** Ring stroke as a fraction of the outer diameter — measured off the app icon. */
private const val STROKE_FRACTION = 0.02f

/** Centre dot diameter as a fraction of the outer diameter — measured off the app icon. */
private const val DOT_FRACTION = 0.13f

/** The ring's own bloom — iOS blurs the ring by 90% of its stroke at 0.6 opacity. */
private const val RING_BLOOM_RADIUS = 0.9f
private const val RING_BLOOM_ALPHA = 0.6f

/** The dot's own bloom — iOS blurs the dot by 45% of its diameter at 0.6 opacity. */
private const val DOT_BLOOM_RADIUS = 0.45f
private const val DOT_BLOOM_ALPHA = 0.6f

/** The tight bright halo — iOS's first `shadow(tint 0.9, radius: size * 0.05)`. */
private const val INNER_HALO_RADIUS = 0.05f
private const val INNER_HALO_ALPHA = 0.9f

/** The wide soft halo it blooms inside — iOS's `shadow(tint 0.5, radius: size * 0.16)`. */
private const val OUTER_HALO_RADIUS = 0.16f
private const val OUTER_HALO_ALPHA = 0.5f

/** Room around the mark for the halos to fade out in, as a fraction of the diameter. */
private const val HALO_MARGIN = 0.5f

/**
 * The Deep mark — a thin ring with a single dot resting at its centre, the
 * shape the app icon carries. Drawn rather than shipped as a raster so it
 * holds the palette and its glow on its own terms: a crisp ring seated inside
 * its own bloom, cream light over the welcome screen's sunrise.
 *
 * Ported from Deep/Deep/Features/Onboarding/Components/DeepLogoMark.swift.
 * Every measurement is a proportion of [size], so the mark can never drift
 * from the icon. iOS builds the halo from a blurred copy plus two stacked
 * shadows. The ring isn't a filled shape, so `Modifier.dropShadow` can't cast
 * it; [glowMask] runs the same passes by hand, blurring alpha masks on a
 * software canvas the way `dropShadow` does internally — a true gaussian on
 * every API level.
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
  Spacer(
    modifier
      .size(size)
      .clearAndSetSemantics {}
      .drawWithCache {
        val diameter = this.size.minDimension
        val stroke = diameter * STROKE_FRACTION
        val ringRadius = diameter / 2f - stroke / 2f
        val dotRadius = diameter * DOT_FRACTION / 2f

        if (isGlowing) {
          val margin = ceil(diameter * HALO_MARGIN)
          val mask = glowMask(diameter, margin.toInt()).asImageBitmap()
          val colorFilter = ColorFilter.tint(tint)
          onDrawBehind {
            drawImage(mask, topLeft = Offset(-margin, -margin), colorFilter = colorFilter)
          }
        } else {
          onDrawBehind {
            drawCircle(color = tint, radius = ringRadius, style = Stroke(width = stroke))
            drawCircle(color = tint, radius = dotRadius)
          }
        }
      },
  )
}

/**
 * The glowing mark as one alpha mask, [margin] px of fade room on every side:
 * the blurred ring and dot beneath the crisp pass, then the two halos, each
 * blurring everything drawn before it — stacked shadows compose on iOS, so
 * the wide halo blooms the tight one's output.
 */
private fun glowMask(diameter: Float, margin: Int): Bitmap {
  val stroke = diameter * STROKE_FRACTION
  val ringRadius = diameter / 2f - stroke / 2f
  val dotRadius = diameter * DOT_FRACTION / 2f
  val extent = ceil(diameter).toInt() + margin * 2
  val center = margin + diameter / 2f

  val mark = Bitmap.createBitmap(extent, extent, Bitmap.Config.ALPHA_8)
  AndroidCanvas(mark).apply {
    val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE
      strokeWidth = stroke
    }
    val dot = Paint(Paint.ANTI_ALIAS_FLAG)

    ring.maskFilter = BlurMaskFilter(stroke * RING_BLOOM_RADIUS, BlurMaskFilter.Blur.NORMAL)
    ring.alpha = (RING_BLOOM_ALPHA * 255).toInt()
    drawCircle(center, center, ringRadius, ring)
    dot.maskFilter = BlurMaskFilter(dotRadius * 2f * DOT_BLOOM_RADIUS, BlurMaskFilter.Blur.NORMAL)
    dot.alpha = (DOT_BLOOM_ALPHA * 255).toInt()
    drawCircle(center, center, dotRadius, dot)

    ring.maskFilter = null
    ring.alpha = 255
    drawCircle(center, center, ringRadius, ring)
    dot.maskFilter = null
    dot.alpha = 255
    drawCircle(center, center, dotRadius, dot)
  }

  val inner = mark.withHalo(diameter * INNER_HALO_RADIUS, INNER_HALO_ALPHA)
  mark.recycle()
  val outer = inner.withHalo(diameter * OUTER_HALO_RADIUS, OUTER_HALO_ALPHA)
  inner.recycle()
  return outer
}

/** This mask over a blurred copy of itself — one iOS `.shadow` with no offset. */
private fun Bitmap.withHalo(radius: Float, alpha: Float): Bitmap {
  val offset = IntArray(2)
  val blurred = extractAlpha(
    Paint().apply { maskFilter = BlurMaskFilter(radius, BlurMaskFilter.Blur.NORMAL) },
    offset,
  )
  val result = Bitmap.createBitmap(width, height, Bitmap.Config.ALPHA_8)
  AndroidCanvas(result).apply {
    drawBitmap(
      blurred,
      offset[0].toFloat(),
      offset[1].toFloat(),
      Paint().apply { this.alpha = (alpha * 255).toInt() },
    )
    drawBitmap(this@withHalo, 0f, 0f, null)
  }
  blurred.recycle()
  return result
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
