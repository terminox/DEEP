package io.appbeyond.freelance.deep.feature.compassion.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.feature.compassion.CompassionIcons
import io.appbeyond.freelance.deep.shared.components.ArtworkPalette
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.tile

// MARK: - Constants

/** The plum vignette across the bottom-trailing corner — iOS's `deepPlum 0.12`, radius 240. */
private const val VIGNETTE_ALPHA = 0.12f
private val VIGNETTE_RADIUS = 240.dp

/** The artwork's rim — iOS's `strokeBorder(.white.opacity(0.35), lineWidth: 0.5)`. */
private const val RIM_ALPHA = 0.35f
private val RIM_WIDTH = 0.5.dp

/** The plum seat under the glyph — iOS's `shadow(deepPlum 0.18, radius: 8, y: 3)`. */
private const val SEAT_ALPHA = 0.18f
private val SEAT_RADIUS = 8.dp
private val SEAT_OFFSET_Y = 3.dp

// MARK: - Motif

/**
 * A cause's visual stand-in until real imagery exists: the palette gradient
 * (iOS's `SoundArtwork` fallback — top-leading to bottom-trailing, with a
 * plum vignette pooled in the far corner) and the cause's glyph floating in
 * soft white on top. Reused at every size — legend chips, list thumbs, tile
 * banners, the cause hero — so a cause reads the same wherever it appears.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/CompassionMotif.swift.
 * At hero scale the glyph can be pushed large, faint and to the trailing edge
 * (an editorial watermark); iOS softens it with a blur, which below API 31 is a
 * no-op, so here the watermark relies on its low opacity alone.
 *
 * @param symbolScale the glyph's size as a fraction of the smaller edge.
 * @param symbolShadow the plum seat under the glyph; off at chip sizes, where a
 *   fixed-radius shadow smears across the whole motif.
 * @param bordered the faint white rim; full-bleed artwork switches it off.
 */
@Composable
fun CompassionMotif(
  symbol: ImageVector,
  palette: ArtworkPalette,
  modifier: Modifier = Modifier,
  cornerRadius: Dp = Dp.tile,
  symbolScale: Float = 0.42f,
  symbolOpacity: Float = 0.92f,
  symbolShadow: Boolean = true,
  symbolAlignment: Alignment = Alignment.Center,
  bordered: Boolean = true,
) {
  val shape: Shape = RoundedCornerShape(cornerRadius)
  BoxWithConstraints(
    modifier
      .clearAndSetSemantics {}
      .clip(shape)
      .background(Brush.linearGradient(palette.colors))
      .then(if (bordered) Modifier.border(RIM_WIDTH, Color.White.copy(alpha = RIM_ALPHA), shape) else Modifier),
    contentAlignment = symbolAlignment,
  ) {
    Canvas(Modifier.matchParentSize()) {
      drawRect(
        brush = Brush.radialGradient(
          colors = listOf(Color.deepPlum.copy(alpha = VIGNETTE_ALPHA), Color.Transparent),
          center = Offset(size.width, size.height),
          radius = VIGNETTE_RADIUS.toPx(),
        ),
      )
    }
    val edge = minOf(maxWidth, maxHeight)
    val glyph = edge * symbolScale
    Icon(
      imageVector = symbol,
      contentDescription = null,
      tint = Color.White.copy(alpha = symbolOpacity),
      modifier = Modifier
        .size(glyph)
        .then(
          if (symbolShadow) {
            Modifier.dropShadow(
              shape = RoundedCornerShape(glyph / 2),
              shadow = Shadow(
                radius = SEAT_RADIUS,
                color = Color.deepPlum.copy(alpha = SEAT_ALPHA),
                offset = DpOffset(0.dp, SEAT_OFFSET_Y),
              ),
            )
          } else {
            Modifier
          },
        ),
    )
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Compassion motifs")
@Composable
private fun CompassionMotifPreview() {
  Column(
    Modifier.fillMaxSize().background(Color.moonCream).padding(16.dp),
    verticalArrangement = Arrangement.spacedBy(16.dp),
  ) {
    Row(Modifier.height(80.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
      CompassionMotif(CompassionIcons.BirdFill, ArtworkPalette.Aurora, Modifier.size(80.dp))
      CompassionMotif(CompassionIcons.CrossFill, ArtworkPalette.Bloom, Modifier.size(80.dp))
      CompassionMotif(CompassionIcons.LeafFill, ArtworkPalette.Mist, Modifier.size(80.dp))
    }
    Box(Modifier.fillMaxWidth().height(180.dp)) {
      CompassionMotif(
        symbol = CompassionIcons.LeafFill,
        palette = ArtworkPalette.Mist,
        modifier = Modifier.fillMaxSize(),
        cornerRadius = 0.dp,
        symbolScale = 1.5f,
        symbolOpacity = 0.2f,
        symbolShadow = false,
        symbolAlignment = Alignment.CenterEnd,
        bordered = false,
      )
    }
  }
}
