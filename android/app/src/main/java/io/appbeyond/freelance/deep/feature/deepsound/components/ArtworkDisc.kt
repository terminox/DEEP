package io.appbeyond.freelance.deep.feature.deepsound.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist

// MARK: - Constants

/** The disc's white — iOS's `.white.opacity(0.9)`. */
private const val DISC_ALPHA = 0.9f

/** Its lift — iOS's `shadow(deepPlum 0.2, …)`. */
private const val DISC_SHADOW_ALPHA = 0.2f

/**
 * The two sizes iOS draws this disc at. [Small] is `HomeTile`'s play button
 * (36pt, a 12pt glyph, `radius: 6, y: 3`); [Large] is `FeatureCard`'s (44pt, a
 * 16pt glyph, `radius: 8, y: 4`).
 */
enum class ArtworkDiscSize(
  val diameter: Dp,
  val glyph: Dp,
  val shadowRadius: Dp,
  val shadowOffsetY: Dp,
) {
  Small(diameter = 36.dp, glyph = 12.dp, shadowRadius = 6.dp, shadowOffsetY = 3.dp),
  Large(diameter = 44.dp, glyph = 16.dp, shadowRadius = 8.dp, shadowOffsetY = 4.dp),
}

// MARK: - Disc

/**
 * The white disc that sits on a collection's artwork: the home tiles' and
 * feature cards' play button (`HomeTile.playButton` / `FeatureCard.playButton`
 * in Deep/Deep/Features/GlobalPause/Components).
 *
 * Only the look; the caller makes it a button. A DEEP Premium collection keeps
 * it — the lock is a badge of its own at the artwork's other corner
 * ([io.appbeyond.freelance.deep.feature.premium.components.PremiumLockBadge]).
 */
@Composable
fun ArtworkDisc(
  size: ArtworkDiscSize,
  modifier: Modifier = Modifier,
) {
  Box(
    modifier
      .size(size.diameter)
      .dropShadow(
        shape = CircleShape,
        shadow = Shadow(
          radius = size.shadowRadius,
          color = Color.deepPlum.copy(alpha = DISC_SHADOW_ALPHA),
          offset = DpOffset(0.dp, size.shadowOffsetY),
        ),
      )
      .background(Color.White.copy(alpha = DISC_ALPHA), CircleShape),
    contentAlignment = Alignment.Center,
  ) {
    Icon(
      imageVector = SoundIcons.Play,
      contentDescription = null,
      tint = Color.deepPlum,
      modifier = Modifier.size(size.glyph),
    )
  }
}

// MARK: - Preview

@Preview(showBackground = true, name = "Artwork discs")
@Composable
private fun ArtworkDiscPreview() {
  DeepTheme {
    Row(
      Modifier
        .background(Color.lavenderMist)
        .padding(Dp.edge),
      horizontalArrangement = Arrangement.spacedBy(16.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      ArtworkDisc(ArtworkDiscSize.Small)
      ArtworkDisc(ArtworkDiscSize.Large)
    }
  }
}
