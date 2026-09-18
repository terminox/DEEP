package io.appbeyond.freelance.deep.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// MARK: - Constants

/** Alpha of the ambient bloom at its core, before it fades outward. */
private const val BLOOM_ALPHA = 0.18f

/** How far the bloom spreads past the card's edge — iOS's shadow `radius: 24`. */
private val BLOOM_SPREAD = 24.dp

/** The bloom's downward offset — iOS's shadow `y: 12`. */
private val BLOOM_OFFSET_Y = 12.dp

/** Layers stacked outward, each fainter, standing in for a gaussian falloff. */
private const val BLOOM_STEPS = 6

/** Alpha of the white wash over the moonCream base — the material stand-in. */
private const val FILL_ALPHA = 0.55f

/** Alpha of the hairline border. */
private const val BORDER_ALPHA = 0.45f

/** Border stroke width — iOS's `lineWidth: 0.5`. */
private val BORDER_WIDTH = 0.5.dp

/** Alpha of the leading-edge tint at its core, fading to nothing. */
private const val TINT_ALPHA = 0.36f

/** How far the leading-edge tint reaches — iOS's `endRadius: 240`. */
private val TINT_RADIUS = 240.dp

// MARK: - Modifier

/**
 * The frosted-card surface: an opaque pale base, a hairline border, a soft
 * lavender bloom beneath it, and an optional identity wash from the leading
 * edge.
 *
 * Ported from Deep/Deep/Theme/FrostedCardStyle.swift. iOS builds this from
 * `.ultraThinMaterial` — a live backdrop blur with no minSdk-26 equivalent
 * (`RenderEffect.createBackdropBlurEffect` needs API 31). The material's
 * *look* is rebuilt without any blur: white at ~55% alpha washed over an
 * opaque moonCream base stands in for the frosted glass. The "ambient bloom"
 * iOS gets for free from `.shadow(color: .lavenderMist.opacity(0.18), radius:
 * 24, y: 12)` is drawn the way
 * [io.appbeyond.freelance.deep.shared.components.AtmosphereBackground] draws
 * its orbs — stacked, fading rounded rects rather than a blurred layer —
 * because a platform elevation shadow (`Modifier.shadow`) reads as a hard
 * grey drop shadow here, not a soft colour bloom, and `Modifier.blur` is a
 * no-op below API 31.
 *
 * @param cornerRadius the card's corner radius.
 * @param tint an optional identity wash bloomed from the leading edge, so a
 *   card can carry the colour of the thing it stands for (a cause, a
 *   collection) without leaving the frosted family. `null` keeps the plain
 *   surface.
 */
fun Modifier.frostedCard(cornerRadius: Dp = Dp.card, tint: Color? = null): Modifier =
  drawBehind {
    val shape = CornerRadius(cornerRadius.toPx())
    val spreadPx = BLOOM_SPREAD.toPx()
    val offsetYPx = BLOOM_OFFSET_Y.toPx()

    // The ambient bloom: layers stacked outward from the card's edge, each
    // larger and fainter, tracing a rough gaussian falloff.
    for (step in BLOOM_STEPS downTo 1) {
      val t = step / BLOOM_STEPS.toFloat()
      val spread = spreadPx * t
      val alpha = BLOOM_ALPHA * (1f - t) * (1f - t)
      drawRoundRect(
        color = Color.lavenderMist.copy(alpha = alpha),
        topLeft = Offset(-spread, offsetYPx - spread),
        size = Size(size.width + spread * 2f, size.height + spread * 2f),
        cornerRadius = CornerRadius(shape.x + spread),
      )
    }

    // The material stand-in.
    drawRoundRect(color = Color.moonCream, cornerRadius = shape)
    drawRoundRect(color = Color.White.copy(alpha = FILL_ALPHA), cornerRadius = shape)

    // The optional identity wash, blooming from the leading edge.
    if (tint != null) {
      drawRoundRect(
        brush = Brush.radialGradient(
          colors = listOf(tint.copy(alpha = TINT_ALPHA), tint.copy(alpha = 0f)),
          center = Offset(0f, size.height / 2f),
          radius = TINT_RADIUS.toPx(),
        ),
        cornerRadius = shape,
      )
    }

    drawRoundRect(
      color = Color.White.copy(alpha = BORDER_ALPHA),
      cornerRadius = shape,
      style = Stroke(width = BORDER_WIDTH.toPx()),
    )
  }

// MARK: - Previews

@Preview(showBackground = true)
@Composable
private fun FrostedCardPreview() {
  Box(
    modifier = Modifier
      .fillMaxSize()
      .background(Color.moonCream)
      .padding(32.dp),
  ) {
    Box(modifier = Modifier.frostedCard().padding(24.dp)) {
      Text("Frosted card", style = DeepType.body, color = Color.deepPlum)
    }
  }
}

@Preview(showBackground = true, name = "Tinted")
@Composable
private fun FrostedCardTintedPreview() {
  Box(
    modifier = Modifier
      .fillMaxSize()
      .background(Color.moonCream)
      .padding(32.dp),
  ) {
    Box(modifier = Modifier.frostedCard(tint = Color.blushPowder).padding(24.dp)) {
      Text("Tinted card", style = DeepType.body, color = Color.deepPlum)
    }
  }
}
