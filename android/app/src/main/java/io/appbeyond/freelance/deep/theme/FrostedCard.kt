package io.appbeyond.freelance.deep.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp

// MARK: - Constants

/** The ambient bloom beneath the card — iOS's `shadow(lavenderMist 0.18, radius: 24, y: 12)`. */
private const val SHADOW_ALPHA = 0.18f
private val SHADOW_RADIUS = 24.dp
private val SHADOW_OFFSET_Y = 12.dp

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
 * opaque moonCream base stands in for the frosted glass. The ambient bloom is
 * `Modifier.dropShadow`, not `Modifier.shadow`: the elevation shadow is a hard
 * grey, while `dropShadow` blurs the shape into a cached bitmap on a software
 * canvas — a true coloured gaussian on every API level, unlike
 * `Modifier.blur` (a no-op below API 31).
 *
 * @param cornerRadius the card's corner radius.
 * @param tint an optional identity wash bloomed from the leading edge, so a
 *   card can carry the colour of the thing it stands for (a cause, a
 *   collection) without leaving the frosted family. `null` keeps the plain
 *   surface.
 */
fun Modifier.frostedCard(cornerRadius: Dp = Dp.card, tint: Color? = null): Modifier =
  dropShadow(
    shape = RoundedCornerShape(cornerRadius),
    shadow = Shadow(
      radius = SHADOW_RADIUS,
      color = Color.lavenderMist.copy(alpha = SHADOW_ALPHA),
      offset = DpOffset(0.dp, SHADOW_OFFSET_Y),
    ),
  ).drawBehind {
    val shape = CornerRadius(cornerRadius.toPx())

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
