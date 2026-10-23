package io.appbeyond.freelance.deep.feature.globalpause.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Image
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.softPress

/**
 * The doorway on Home into Fuku's Lounge — DJ Fuku at his desk, full-bleed,
 * with a plum wash under the copy in the `BreatheHeroCard` family. Tapping
 * pushes the lounge through the coordinator.
 *
 * The ON AIR badge burns only while Fuku's nightly set actually runs, off the
 * same `isFukuOnAir` the lounge follows — so the card is how you find out the
 * room has gone live, and it can never advertise a broadcast the lounge is not
 * playing.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Components/DJFukuLoungeCard.swift,
 * with `BreatheHeroCard`'s Android answer to the progressive blur: there is no
 * backdrop blur below API 31, so the foot is a deeper plum band instead.
 */
@Composable
fun DJFukuLoungeCard(
  isOnAir: Boolean,
  onOpen: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val shape = RoundedCornerShape(Dp.card)
  val a11yLabel = stringResource(
    if (isOnAir) R.string.pause_lounge_card_a11y_on_air else R.string.pause_lounge_card_a11y,
  )

  Box(
    modifier
      .fillMaxWidth()
      .height(CARD_HEIGHT)
      .softPress()
      .dropShadow(
        shape = shape,
        shadow = Shadow(
          radius = 22.dp,
          color = Color.lavenderMist.copy(alpha = 0.28f),
          offset = DpOffset(0.dp, 12.dp),
        ),
      )
      .clip(shape)
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        onClick = onOpen,
      )
      .clearAndSetSemantics {
        contentDescription = a11yLabel
        role = Role.Button
        onClick { onOpen(); true }
      },
  ) {
    Image(
      painter = painterResource(R.drawable.dj_fuku_hero),
      contentDescription = null,
      contentScale = ContentScale.Crop,
      modifier = Modifier.fillMaxSize(),
    )
    // The image's lower third is bright cream (desk, mug), so the wash runs
    // deeper than the Breathe card's.
    Box(
      Modifier
        .fillMaxSize()
        .background(
          Brush.verticalGradient(
            colorStops = arrayOf(
              0.45f to Color.Transparent,
              1f to Color.deepPlum.copy(alpha = WASH_ALPHA),
            ),
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
      Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
          stringResource(R.string.pause_lounge_card_title),
          style = DeepType.displayTitle,
          color = Color.White,
          maxLines = 2,
          overflow = TextOverflow.Ellipsis,
        )
        Text(
          stringResource(R.string.pause_lounge_card_body),
          style = DeepType.caption,
          color = Color.White.copy(alpha = 0.85f),
        )
      }
      ChevronDisc()
    }

    AnimatedVisibility(
      visible = isOnAir,
      enter = fadeIn(exhale()),
      exit = fadeOut(exhale()),
      modifier = Modifier
        .align(Alignment.TopEnd)
        .padding(CONTENT_PADDING),
    ) {
      OnAirPill()
    }
  }
}

/** Decorative: the whole card already navigates, so a chevron says "go". */
@Composable
private fun ChevronDisc() {
  Box(
    Modifier
      .size(48.dp)
      .dropShadow(
        shape = CircleShape,
        shadow = Shadow(radius = 8.dp, color = Color.deepPlum.copy(alpha = 0.2f), offset = DpOffset(0.dp, 4.dp)),
      )
      .background(Color.White.copy(alpha = 0.85f), CircleShape),
    contentAlignment = Alignment.Center,
  ) {
    Icon(SoundIcons.ChevronForward, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(22.dp))
  }
}

private val CARD_HEIGHT = 220.dp
private val CONTENT_PADDING = 18.dp
private const val WASH_ALPHA = 0.7f

@Preview(showBackground = true, name = "Fuku's Lounge card")
@Composable
private fun DJFukuLoungeCardPreview() {
  DeepTheme {
    Box {
      AtmosphereBackground()
      DJFukuLoungeCard(isOnAir = false, onOpen = {}, modifier = Modifier.padding(Dp.edge))
    }
  }
}

@Preview(showBackground = true, name = "Fuku's Lounge card — on air")
@Composable
private fun DJFukuLoungeCardOnAirPreview() {
  DeepTheme {
    Box {
      AtmosphereBackground()
      DJFukuLoungeCard(isOnAir = true, onOpen = {}, modifier = Modifier.padding(Dp.edge))
    }
  }
}
