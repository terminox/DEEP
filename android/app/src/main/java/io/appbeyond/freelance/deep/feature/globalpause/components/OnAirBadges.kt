package io.appbeyond.freelance.deep.feature.globalpause.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.nightHorizon

/**
 * The little live badge for Fuku's Lounge — a softly pulsing dot beside
 * "ON AIR". The pulse breathes on [exhale] and holds still under reduce motion.
 *
 * Given an [onTap] it becomes the lounge's mute control: the badge already
 * means "Fuku is playing", so tapping it to stop the sound needs no chrome of
 * its own. Silenced, the dot dims and stops breathing — the set is still on
 * air, the member is simply not listening. Without [onTap] it is a plain
 * badge, which is what [DJFukuLoungeCard] needs: that whole card is a button.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Components/OnAirPill.swift.
 */
@Composable
fun OnAirPill(
  modifier: Modifier = Modifier,
  isMuted: Boolean = false,
  onTap: (() -> Unit)? = null,
) {
  val label = stringResource(if (isMuted) R.string.pause_on_air_muted else R.string.pause_on_air)
  val hint = stringResource(if (isMuted) R.string.pause_on_air_unmute_hint else R.string.pause_on_air_mute_hint)

  val semantics = if (onTap != null) {
    Modifier
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        onClick = onTap,
      )
      .clearAndSetSemantics {
        contentDescription = label
        role = Role.Button
        onClick(label = hint) { onTap(); true }
      }
  } else {
    Modifier.clearAndSetSemantics { contentDescription = label }
  }

  Row(
    modifier
      .then(semantics)
      .background(Color.White.copy(alpha = PILL_FILL_ALPHA), RoundedCornerShape(Dp.chip))
      .padding(horizontal = 9.dp, vertical = 5.dp),
    horizontalArrangement = Arrangement.spacedBy(4.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    BreathingDot(breathes = !isMuted, restingAlpha = if (isMuted) MUTED_DOT_ALPHA else 1f)
    val textAlpha by animateFloatAsState(if (isMuted) 0.5f else 1f, exhale(), label = "on-air-text")
    Text(
      text = stringResource(R.string.pause_on_air_badge),
      style = DeepType.micro,
      color = Color.deepPlum,
      modifier = Modifier.alpha(textAlpha),
    )
    AnimatedVisibility(visible = isMuted, enter = fadeIn(exhale()), exit = fadeOut(exhale())) {
      Icon(
        imageVector = GlobalPauseIcons.SpeakerSlash,
        contentDescription = null,
        tint = Color.deepPlum.copy(alpha = 0.5f),
        modifier = Modifier.size(10.dp),
      )
    }
  }
}

/**
 * The card's LIVE badge — the [OnAirPill] recipe seated on the night sky, so it
 * runs near-opaque: half-white goes mid-grey there and drowns the plum label.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Components/LiveBadgeView.swift.
 */
@Composable
fun LiveBadge(modifier: Modifier = Modifier) {
  val label = stringResource(R.string.pause_live_badge)
  val spoken = stringResource(R.string.pause_live_spoken)
  Row(
    modifier
      .clearAndSetSemantics { contentDescription = spoken }
      .background(Color.White.copy(alpha = LIVE_FILL_ALPHA), RoundedCornerShape(Dp.chip))
      .padding(horizontal = 9.dp, vertical = 5.dp),
    horizontalArrangement = Arrangement.spacedBy(4.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    BreathingDot(breathes = true, restingAlpha = 1f)
    Text(text = label, style = DeepType.micro, color = Color.deepPlum)
  }
}

/** The pulsing dot both badges share. */
@Composable
private fun BreathingDot(breathes: Boolean, restingAlpha: Float) {
  val reduceMotion = rememberReduceMotion()
  val alpha = if (breathes && !reduceMotion) {
    val pulse = rememberInfiniteTransition(label = "badge-pulse")
    pulse.animateFloat(
      initialValue = 1f,
      targetValue = PULSE_LOW,
      animationSpec = infiniteRepeatable(exhale(), RepeatMode.Reverse),
      label = "badge-pulse-alpha",
    ).value
  } else {
    restingAlpha
  }
  Box(
    Modifier
      .size(6.dp)
      .alpha(alpha)
      .background(Color.blushPowder, CircleShape),
  )
}

private const val PILL_FILL_ALPHA = 0.5f
private const val LIVE_FILL_ALPHA = 0.85f
private const val PULSE_LOW = 0.4f
private const val MUTED_DOT_ALPHA = 0.25f

@Preview(showBackground = true, name = "On air pill")
@Composable
private fun OnAirPillPreview() {
  DeepTheme {
    Box {
      AtmosphereBackground()
      Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        OnAirPill()
        OnAirPill(onTap = {})
        OnAirPill(isMuted = true, onTap = {})
      }
    }
  }
}

@Preview(name = "Live badge")
@Composable
private fun LiveBadgePreview() {
  DeepTheme {
    Box(Modifier.background(Color.nightHorizon).padding(24.dp)) { LiveBadge() }
  }
}
