package io.appbeyond.freelance.deep.feature.onboarding.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

private val VERTICAL_PADDING = 18.dp
private val ICON_SPACING = 10.dp
private val ICON_SIZE = 20.dp
private const val DISABLED_ALPHA = 0.5f
private const val BORDER_ALPHA = 0.6f
private val BORDER_WIDTH = 0.5.dp

/** The bloom beneath the pill — iOS's `shadow(lavenderMist 0.35, radius: 20, y: 10)`. */
private const val BLOOM_ALPHA = 0.35f
private val BLOOM_RADIUS = 20.dp
private val BLOOM_OFFSET_Y = 10.dp

/**
 * The soft full-width pill that moves onboarding forward — "Begin",
 * "Continue", "Create account".
 *
 * Ported from Deep/Deep/Features/Onboarding/Components/OnboardingPrimaryButton.swift:
 * a moonCream capsule with a white hairline rim, lifted on a lavender bloom.
 * Disabled, it fades to half and ignores taps — the dimmed "Next" before a
 * choice is made, never an error. The bloom is `Modifier.dropShadow`, as in
 * `frostedCard` and `DeepChip` — a real coloured blur on every API level,
 * where `Modifier.shadow` would cast a grey elevation shadow.
 *
 * @param interactive false draws the pill with no pointer handling at all —
 *   for a freeze-frame that touches must fall straight through (the welcome
 *   screen's ripple still). Distinct from [enabled], which dims it.
 */
@Composable
fun OnboardingPrimaryButton(
  title: String,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
  icon: ImageVector? = null,
  enabled: Boolean = true,
  interactive: Boolean = true,
) {
  val alpha by animateFloatAsState(
    targetValue = if (enabled) 1f else DISABLED_ALPHA,
    animationSpec = exhale(),
    label = "primary-button-alpha",
  )
  val shape = RoundedCornerShape(Dp.chip)

  Row(
    modifier = modifier
      .fillMaxWidth()
      // ModulateAlpha, not an offscreen layer: a layer is clipped to the
      // button's bounds, which cut the bloom below the pill into a hard-edged
      // rectangle while disabled.
      .graphicsLayer {
        this.alpha = alpha
        compositingStrategy = CompositingStrategy.ModulateAlpha
      }
      .pillBloom()
      .border(BORDER_WIDTH, Color.White.copy(alpha = BORDER_ALPHA), shape)
      .then(
        if (interactive) {
          Modifier
            .softPress()
            .clickable(
              enabled = enabled,
              role = Role.Button,
              interactionSource = null,
              indication = null,
              onClick = onClick,
            )
        } else {
          Modifier
        },
      )
      .padding(vertical = VERTICAL_PADDING),
    horizontalArrangement = Arrangement.spacedBy(ICON_SPACING, Alignment.CenterHorizontally),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    if (icon != null) {
      Icon(icon, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(ICON_SIZE))
    }
    Text(text = title, style = DeepType.sectionTitle, color = Color.deepPlum)
  }
}

/** The capsule fill and the lavender bloom it floats on. */
private fun Modifier.pillBloom(): Modifier =
  dropShadow(
    shape = RoundedCornerShape(percent = 50),
    shadow = Shadow(
      radius = BLOOM_RADIUS,
      color = Color.lavenderMist.copy(alpha = BLOOM_ALPHA),
      offset = DpOffset(0.dp, BLOOM_OFFSET_Y),
    ),
  ).drawBehind {
    drawRoundRect(color = Color.moonCream, cornerRadius = CornerRadius(size.height / 2f))
  }

@Preview(showBackground = true, name = "Primary button")
@Composable
private fun OnboardingPrimaryButtonPreview() {
  OnboardingPreviewBackdrop {
    Column(
      modifier = Modifier.padding(horizontal = Dp.edge, vertical = Dp.rhythm),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
    ) {
      OnboardingPrimaryButton(title = "Continue", onClick = {})
      OnboardingPrimaryButton(title = "Continue with Email", icon = OnboardingGlyphs.Envelope, onClick = {})
      OnboardingPrimaryButton(title = "Next", enabled = false, onClick = {})
    }
  }
}
