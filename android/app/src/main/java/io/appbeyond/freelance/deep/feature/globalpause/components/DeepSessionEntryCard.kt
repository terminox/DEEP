package io.appbeyond.freelance.deep.feature.globalpause.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import io.appbeyond.freelance.deep.feature.deepsound.components.rememberBalancingBreath
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.softLilac
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

/** iOS's `.padding(20)` inside the frosted card. */
private val CARD_PADDING = 20.dp

/** Copy to play circle — `HStack(spacing: 16)`; the copy's own `VStack(spacing: 5)`. */
private val ROW_SPACING = 16.dp
private val TEXT_SPACING = 5.dp

/** The gradient play circle — iOS's 54pt disc with an 18pt glyph. */
private val PLAY_SIZE = 54.dp
private val PLAY_GLYPH = 18.dp

/** Its bloom — iOS's `shadow(lavenderMist 0.4, radius: 12, y: 6)`. */
private const val PLAY_BLOOM_ALPHA = 0.4f
private val PLAY_BLOOM_RADIUS = 12.dp
private val PLAY_BLOOM_OFFSET_Y = 6.dp

// MARK: - Card

/**
 * Home's doorway into a guided DEEP Session: a "DEEP SESSION" eyebrow, the
 * session's title and its own line, and a gradient play circle. The whole card
 * opens the session's threshold through [onOpen] — the coordinator's
 * `openDeepSession`.
 *
 * Ported from Deep/Deep/Features/DeepSession/Components/DeepSessionEntryCard.swift
 * (705b6b4), where Home offers `DeepSessionLibrary.balancingBreath` — here
 * [rememberBalancingBreath], the same practice DEEP Sound's Breathe card opens.
 * The tagline, not a length: how long is chosen on the threshold, so no card
 * can promise a number for it.
 */
@Composable
fun DeepSessionEntryCard(
  session: DeepSession,
  onOpen: (DeepSession) -> Unit,
  modifier: Modifier = Modifier,
) {
  val label = stringResource(R.string.home_session_card_a11y, session.title)

  Row(
    modifier
      .fillMaxWidth()
      .softPress()
      .frostedCard()
      .clickable(interactionSource = null, indication = null) { onOpen(session) }
      .clearAndSetSemantics {
        contentDescription = label
        role = Role.Button
        onClick { onOpen(session); true }
      }
      .padding(CARD_PADDING),
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    // Weighted rather than followed by a Spacer, so the copy keeps its width
    // instead of bidding against one.
    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TEXT_SPACING)) {
      Text(stringResource(R.string.deepsound_breathe_eyebrow), style = DeepType.micro, color = Color.driftGrey)
      Text(session.title, style = DeepType.displayTitle, color = Color.deepPlum)
      Text(session.tagline, style = DeepType.caption, color = Color.driftGrey)
    }
    PlayCircle()
  }
}

/** Decorative: the whole card is the button. */
@Composable
private fun PlayCircle() {
  Box(
    Modifier
      .size(PLAY_SIZE)
      .dropShadow(
        shape = CircleShape,
        shadow = Shadow(
          radius = PLAY_BLOOM_RADIUS,
          color = Color.lavenderMist.copy(alpha = PLAY_BLOOM_ALPHA),
          offset = DpOffset(0.dp, PLAY_BLOOM_OFFSET_Y),
        ),
      )
      .background(Brush.linearGradient(listOf(Color.lavenderMist, Color.softLilac)), CircleShape),
    contentAlignment = Alignment.Center,
  ) {
    Icon(SoundIcons.Play, contentDescription = null, tint = Color.White, modifier = Modifier.size(PLAY_GLYPH))
  }
}

// MARK: - Preview

@Preview(showBackground = true, name = "DEEP Session entry")
@Composable
private fun DeepSessionEntryCardPreview() {
  DeepTheme {
    Box {
      AtmosphereBackground(Modifier.matchParentSize(), animated = false)
      DeepSessionEntryCard(
        session = rememberBalancingBreath(),
        onOpen = {},
        modifier = Modifier.padding(Dp.edge),
      )
    }
  }
}
