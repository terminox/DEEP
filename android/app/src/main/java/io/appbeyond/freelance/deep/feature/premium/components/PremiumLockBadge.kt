package io.appbeyond.freelance.deep.feature.premium.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.settle
import io.appbeyond.freelance.deep.theme.tile

// MARK: - Constants

/** The glyph's share of the seat — iOS's `diameter * 0.42`. */
private const val GLYPH_SCALE = 0.42f

/** The lock's ink — iOS's `deepPlum.opacity(0.7)`. */
private const val GLYPH_ALPHA = 0.7f

/** The seat — iOS's `.white.opacity(0.65)` circle, rimmed 0.5pt at 0.4. */
private const val SEAT_ALPHA = 0.65f
private const val RIM_ALPHA = 0.4f
private val RIM_WIDTH = 0.5.dp

/**
 * The sizes the badge is worn at, by what it sits on — named for the
 * placement rather than the number, the way [io.appbeyond.freelance.deep.feature.deepsound.components.ArtworkDiscSize]
 * names its two.
 */
enum class PremiumLockSize(val diameter: Dp) {
  /** A shelf tile, a home tile or a feature card's artwork — iOS's default 28. */
  Artwork(28.dp),

  /** A collection list row's art, a track row, a plant's portrait — iOS's 22. */
  Row(22.dp),

  /** A playlist row's smaller art — iOS's 20. */
  Compact(20.dp),
}

// MARK: - Badge

/**
 * The one mark DEEP Premium content wears before it is tapped: a rounded lock
 * at reduced opacity, seated in a soft translucent circle — the same white
 * seat the artwork play buttons and header icons sit in, a size down.
 *
 * Ported from Deep/Deep/Features/Premium/Components/PremiumLockBadge.swift. One
 * component everywhere, so premium reads the same on a shelf tile, a home
 * card, a list row, a playlist row, inline in a collection's track list and
 * on a plant's portrait. Callers decide *whether* to show it, always through
 * `PremiumGate`. It names itself to TalkBack as "Part of DEEP Premium".
 *
 * The glyph is DEEP Sound's solid-bodied lock, the nearest this app has to
 * iOS's semibold rounded `lock.fill`.
 */
@Composable
fun PremiumLockBadge(
  modifier: Modifier = Modifier,
  size: PremiumLockSize = PremiumLockSize.Artwork,
) {
  val label = stringResource(R.string.premium_part_of)
  Box(
    modifier
      .size(size.diameter)
      .clip(CircleShape)
      .background(Color.White.copy(alpha = SEAT_ALPHA), CircleShape)
      .border(RIM_WIDTH, Color.White.copy(alpha = RIM_ALPHA), CircleShape)
      .clearAndSetSemantics { contentDescription = label },
    contentAlignment = Alignment.Center,
  ) {
    Icon(
      imageVector = SoundIcons.Lock,
      contentDescription = null,
      tint = Color.deepPlum.copy(alpha = GLYPH_ALPHA),
      modifier = Modifier.size(size.diameter * GLYPH_SCALE),
    )
  }
}

/**
 * The badge where it lives inline (a track row, before its length): present
 * only while [visible], fading in and out on `settle` so subscribing removes
 * it in place.
 */
@Composable
fun PremiumLockBadge(
  visible: Boolean,
  modifier: Modifier = Modifier,
  size: PremiumLockSize = PremiumLockSize.Row,
) {
  AnimatedVisibility(
    visible = visible,
    modifier = modifier,
    enter = fadeIn(settle()),
    exit = fadeOut(settle()),
    label = "premium-lock-badge",
  ) {
    PremiumLockBadge(size = size)
  }
}

/**
 * Seats the badge in a corner of a piece of artwork when [isLocked] — iOS's
 * `.premiumLockBadge(_:diameter:alignment:inset:)`. Called inside the `Box`
 * that holds the artwork; nothing is drawn otherwise, so subscribing removes
 * it in place.
 */
@Composable
fun BoxScope.PremiumLockCorner(
  isLocked: Boolean,
  size: PremiumLockSize = PremiumLockSize.Artwork,
  alignment: Alignment = Alignment.TopEnd,
  inset: Dp = 8.dp,
) {
  PremiumLockBadge(
    visible = isLocked,
    size = size,
    modifier = Modifier
      .align(alignment)
      .padding(inset),
  )
}

// MARK: - Preview

@Preview(showBackground = true, name = "Premium lock badge")
@Composable
private fun PremiumLockBadgePreview() {
  DeepTheme {
    Box {
      AtmosphereBackground(Modifier.matchParentSize(), animated = false)
      Column(
        Modifier.padding(Dp.edge),
        verticalArrangement = Arrangement.spacedBy(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
      ) {
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.CenterVertically) {
          PremiumLockBadge(size = PremiumLockSize.Compact)
          PremiumLockBadge(size = PremiumLockSize.Row)
          PremiumLockBadge(size = PremiumLockSize.Artwork)
        }
        Box {
          ArtworkImage(
            url = null,
            palette = "tide",
            contentDescription = null,
            modifier = Modifier
              .size(150.dp)
              .clip(RoundedCornerShape(Dp.tile)),
          )
          PremiumLockCorner(isLocked = true)
        }
      }
    }
  }
}
