package io.appbeyond.freelance.deep.feature.deepsound.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

/** The card's editorial photograph — the same Unsplash sky iOS ships. */
private const val IMAGE_URL = "https://images.unsplash.com/photo-1499346030926-9a72daac6c63?w=600&q=80"

private val CARD_HEIGHT = 220.dp
private val CONTENT_PADDING = 18.dp

/** The lavender lift under the card — iOS's `shadow(lavenderMist 0.28, radius: 22, y: 12)`. */
private const val CARD_SHADOW_ALPHA = 0.28f
private val CARD_SHADOW_RADIUS = 22.dp
private val CARD_SHADOW_OFFSET_Y = 12.dp

/** iOS's legibility wash — clear at the card's middle, plum at its foot. */
private const val WASH_ALPHA = 0.28f

/**
 * The stand-in for iOS's progressive blur: a plum band over the bottom 80dp,
 * strongest at the edge. See [BreatheHeroCard] for why it is not a blur.
 */
private val FOOT_BAND_HEIGHT = 80.dp
private const val FOOT_BAND_ALPHA = 0.16f

private const val EYEBROW_ALPHA = 0.9f
private const val PATTERN_ALPHA = 0.85f

/** The decorative "go" disc — iOS's 48pt white 0.85 circle with its plum shadow. */
private val CHEVRON_DISC_SIZE = 48.dp
private val CHEVRON_GLYPH_SIZE = 20.dp
private const val CHEVRON_DISC_ALPHA = 0.85f
private const val CHEVRON_SHADOW_ALPHA = 0.2f
private val CHEVRON_SHADOW_RADIUS = 8.dp
private val CHEVRON_SHADOW_OFFSET_Y = 4.dp

/** DEEP Session's default rounds — `DeepSessionLibrary.balancingBreath`'s `cycles: 6`. */
private const val BALANCING_BREATH_CYCLES = 6

// MARK: - Card

/**
 * The large editorial doorway at the top of the DEEP Sound home — the bridge
 * into DEEP Session. The whole card opens the session's threshold; unlike a
 * collection tile there is nothing to play in place, so a quiet chevron disc
 * stands where a play button would, saying "go" rather than "play".
 *
 * Ported from Deep/Deep/Features/DeepSound/Components/BreatheHeroCard.swift.
 * One deliberate difference: iOS lays a `VariableBlurView` over the bottom
 * 80pt so the copy reads over bright cloud. There is no backdrop blur below
 * API 31, and animating a blur anywhere near the atmosphere turns its orbs into
 * hard discs — so the foot is a plum band instead, under the same centre-to-foot
 * wash iOS draws.
 *
 * @param session the practice the card opens — see [rememberBalancingBreath].
 * @param onOpen asks the coordinator to push the session's threshold.
 */
@Composable
fun BreatheHeroCard(
  session: DeepSession,
  onOpen: (DeepSession) -> Unit,
  modifier: Modifier = Modifier,
) {
  val shape = RoundedCornerShape(Dp.card)
  val a11yLabel = stringResource(R.string.deepsound_breathe_a11y)

  Box(
    modifier
      .fillMaxWidth()
      .height(CARD_HEIGHT)
      .softPress()
      .dropShadow(
        shape = shape,
        shadow = Shadow(
          radius = CARD_SHADOW_RADIUS,
          color = Color.lavenderMist.copy(alpha = CARD_SHADOW_ALPHA),
          offset = DpOffset(0.dp, CARD_SHADOW_OFFSET_Y),
        ),
      )
      .clip(shape)
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        onClick = { onOpen(session) },
      )
      .clearAndSetSemantics {
        contentDescription = a11yLabel
        role = Role.Button
        onClick { onOpen(session); true }
      },
  ) {
    ArtworkImage(
      url = IMAGE_URL,
      // iOS's `.mist`; Android's ArtworkImage resolves an unknown name to the
      // app's own lavender, which is what mist reads as anyway.
      palette = null,
      modifier = Modifier.fillMaxSize(),
    )
    Box(
      Modifier
        .fillMaxSize()
        .background(
          Brush.verticalGradient(
            colorStops = arrayOf(
              0.5f to Color.Transparent,
              1f to Color.deepPlum.copy(alpha = WASH_ALPHA),
            ),
          ),
        ),
    )
    Box(
      Modifier
        .align(Alignment.BottomCenter)
        .fillMaxWidth()
        .height(FOOT_BAND_HEIGHT)
        .background(
          Brush.verticalGradient(
            listOf(Color.Transparent, Color.deepPlum.copy(alpha = FOOT_BAND_ALPHA)),
          ),
        ),
    )

    Row(
      Modifier
        .align(Alignment.BottomStart)
        .fillMaxWidth()
        .padding(CONTENT_PADDING),
      verticalAlignment = Alignment.Bottom,
    ) {
      Column(
        // Weighted rather than followed by a Spacer, so the copy keeps its
        // width instead of bidding against one.
        Modifier.weight(1f),
        verticalArrangement = Arrangement.spacedBy(4.dp),
      ) {
        Text(
          stringResource(R.string.deepsound_breathe_eyebrow),
          style = DeepType.micro,
          color = Color.White.copy(alpha = EYEBROW_ALPHA),
        )
        Text(
          stringResource(R.string.deepsound_breathe_title),
          style = DeepType.displayTitle,
          color = Color.White,
        )
        Text(
          stringResource(
            R.string.deepsound_breathe_pattern,
            session.inhale.inWholeSeconds.toInt(),
            session.exhale.inWholeSeconds.toInt(),
          ),
          style = DeepType.caption,
          color = Color.White.copy(alpha = PATTERN_ALPHA),
        )
      }
      ChevronDisc()
    }
  }
}

/**
 * Reads like a collection's play button, but the whole card already navigates —
 * so this is decorative, and never a second tap target.
 */
@Composable
private fun ChevronDisc() {
  Box(
    Modifier
      .size(CHEVRON_DISC_SIZE)
      .dropShadow(
        shape = CircleShape,
        shadow = Shadow(
          radius = CHEVRON_SHADOW_RADIUS,
          color = Color.deepPlum.copy(alpha = CHEVRON_SHADOW_ALPHA),
          offset = DpOffset(0.dp, CHEVRON_SHADOW_OFFSET_Y),
        ),
      )
      .background(Color.White.copy(alpha = CHEVRON_DISC_ALPHA), CircleShape),
    contentAlignment = Alignment.Center,
  ) {
    Icon(
      SoundIcons.ChevronForward,
      contentDescription = null,
      tint = Color.deepPlum,
      modifier = Modifier.size(CHEVRON_GLYPH_SIZE),
    )
  }
}

// MARK: - Session

/**
 * The daily practice the card opens: slow rounds of 4s in / 6s out, six rounds
 * as the shortest offer — iOS's `DeepSessionLibrary.balancingBreath`.
 *
 * Built at the UI edge because [DeepSession] keeps its copy as plain strings
 * (see its KDoc), and keyed on that copy so a language switch renames it. The
 * id matches the one Global Pause's entry card uses — it is the same practice.
 */
@Composable
fun rememberBalancingBreath(): DeepSession {
  val title = stringResource(R.string.deepsound_balancing_breath_title)
  val tagline = stringResource(R.string.deepsound_balancing_breath_tagline)
  return remember(title, tagline) {
    DeepSession(
      id = "balancing-breath",
      title = title,
      tagline = tagline,
      cycles = BALANCING_BREATH_CYCLES,
    )
  }
}

// MARK: - Preview

@Preview(showBackground = true, name = "Breathe hero card")
@Composable
private fun BreatheHeroCardPreview() {
  DeepTheme {
    Box(Modifier.background(Color.moonCream).padding(Dp.edge)) {
      BreatheHeroCard(session = rememberBalancingBreath(), onOpen = {})
    }
  }
}
