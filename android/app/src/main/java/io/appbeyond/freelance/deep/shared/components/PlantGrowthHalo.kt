package io.appbeyond.freelance.deep.shared.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.feature.appshell.DeepIcons
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.fern
import io.appbeyond.freelance.deep.theme.meadow
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.sage
import io.appbeyond.freelance.deep.theme.softLilac

// MARK: - Constants

/** The track the arc rides — iOS's `GardenColor.meadow.opacity(0.55)`. */
private const val TRACK_ALPHA = 0.55f

/** The settled glow once the ring closes — iOS's `shadow(fern 0.3, radius: 6)`. */
private const val COMPLETE_GLOW_ALPHA = 0.3f
private val COMPLETE_GLOW_RADIUS = 6.dp

/** Where the rim vignette starts, as a fraction of the portrait's radius (iOS: 0.3d of 0.5d). */
private const val VIGNETTE_START = 0.6f

/** The rim vignette's edge — iOS's `softLilac.opacity(0.22)`. */
private const val VIGNETTE_ALPHA = 0.22f

/** The hairline rim — iOS's `strokeBorder(.white.opacity(0.35), lineWidth: 0.5)`. */
private const val RIM_ALPHA = 0.35f
private val RIM_WIDTH = 0.5.dp

// MARK: - Halo

/**
 * The plant's current form inside a slow ring of growth. The portrait is the
 * stage's mascot via [ArtworkImage] — falling back to [fallbackUrl] (the
 * plant's catalog art), then to the palette gradient with a leaf, while art
 * loads or none exists — cropped to a soft orb, with a rim vignette melting the
 * edge into the frost so it doesn't sit like a sticker. The halo fills with the
 * exhale motion as sunlight banks, and once the ring closes it settles into a
 * gentle fern glow.
 *
 * The arc glows into the card rather than sitting on it — the same blurred,
 * dimmed copy [CompassionRing] gives every ring in the app, which is what draws
 * it — and the track it rides is `meadow`, so the distance still to go reads as
 * green rather than as an absence. The ring is the plant, so it stays green;
 * the gold beside it belongs to the sunlight that fills it.
 *
 * Ported from `PlantGrowthHalo` in
 * Deep/Deep/Features/MindGarden/Components/GardenGrowthCard.swift. Shared, not
 * feature-local, because the reward ritual's garden step wears it too. Purely
 * visual: the caller owns the accessibility summary.
 *
 * @param progress fraction toward the next form, `0..1`; 1 once fully grown.
 * @param portraitUrl the stage's own portrait (mascot, else its backdrop).
 * @param fallbackUrl shown when the stage has no portrait of its own, so a
 *   half-authored ladder still pictures the plant instead of a gradient.
 * @param palette the plant's artwork palette name, behind everything.
 */
@Composable
fun PlantGrowthHalo(
  progress: Float,
  portraitUrl: String?,
  modifier: Modifier = Modifier,
  fallbackUrl: String? = null,
  palette: String? = null,
  portraitDiameter: Dp = 84.dp,
  ringGap: Dp = 5.dp,
  ringWidth: Dp = 3.5.dp,
) {
  val clamped = progress.coerceIn(0f, 1f)
  val glowAlpha by animateFloatAsState(
    targetValue = if (progress >= 1f) COMPLETE_GLOW_ALPHA else 0f,
    animationSpec = exhale(),
    label = "halo-glow",
  )
  val totalDiameter = portraitDiameter + (ringGap + ringWidth) * 2

  CompassionRing(
    segments = listOf(RingSegment(share = clamped, colors = listOf(Color.sage, Color.fern))),
    lineWidth = ringWidth,
    gap = 0f,
    trackColor = Color.meadow.copy(alpha = TRACK_ALPHA),
    glowColor = Color.fern.copy(alpha = glowAlpha),
    glowRadius = COMPLETE_GLOW_RADIUS,
    modifier = modifier.size(totalDiameter),
  ) {
    ArtworkImage(
      url = portraitUrl ?: fallbackUrl,
      palette = palette,
      placeholderIcon = DeepIcons.Leaf,
      modifier = Modifier
        .size(portraitDiameter)
        .clip(CircleShape)
        .rimVignette()
        .border(RIM_WIDTH, Color.White.copy(alpha = RIM_ALPHA), CircleShape),
    )
  }
}

/** Melts the portrait's edge into the frost: clear at 0.6r, softLilac 0.22 at the rim. */
private fun Modifier.rimVignette(): Modifier = drawWithContent {
  drawContent()
  drawCircle(
    brush = Brush.radialGradient(
      VIGNETTE_START to Color.softLilac.copy(alpha = 0f),
      1f to Color.softLilac.copy(alpha = VIGNETTE_ALPHA),
      center = center,
      radius = size.minDimension / 2f,
    ),
  )
}

// MARK: - Previews

@Preview(showBackground = true, name = "Growth halo")
@Composable
private fun PlantGrowthHaloPreview() {
  Box(Modifier.fillMaxSize().background(Color.moonCream)) {
    AtmosphereBackground(animated = false)
    Row(
      modifier = Modifier.padding(Dp.edge),
      horizontalArrangement = Arrangement.spacedBy(16.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      // No urls: the gradient and leaf stand in, as they do while art loads.
      PlantGrowthHalo(progress = 0f, portraitUrl = null, palette = "meadow")
      PlantGrowthHalo(progress = 0.34f, portraitUrl = null, palette = "dawn")
      PlantGrowthHalo(progress = 1f, portraitUrl = null, palette = "tide")
    }
  }
}

@Preview(showBackground = true, name = "Growth halo — large")
@Composable
private fun PlantGrowthHaloLargePreview() {
  Box(Modifier.fillMaxSize().background(Color.moonCream), contentAlignment = Alignment.Center) {
    AtmosphereBackground(animated = false)
    PlantGrowthHalo(
      progress = 0.62f,
      portraitUrl = null,
      palette = "bloom",
      portraitDiameter = 180.dp,
      ringGap = 8.dp,
      ringWidth = 6.dp,
    )
  }
}
