package io.appbeyond.freelance.deep.feature.compassion.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.feature.compassion.CompassionIcons
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.settle
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

/** The capsule's bloom — iOS's `shadow(lavenderMist 0.35, radius: 18, y: 10)`. */
private const val BLOOM_ALPHA = 0.35f
private val BLOOM_RADIUS = 18.dp
private val BLOOM_OFFSET_Y = 10.dp

/** A capsule with nothing to commit — dimmed, never relabelled. */
private const val DISABLED_ALPHA = 0.45f

// MARK: - Capsule

/**
 * The house gradient CTA the giving surfaces share: a lavenderMist →
 * blushPowder capsule, a white heart, a white sectionTitle label — iOS's
 * `SendAHeartBar.sendButton`, the cause card's donate capsule, and the donate
 * sheet's action, which all draw the same recipe.
 *
 * One title for the life of a screen: when there is nothing to commit the
 * capsule dims and ignores taps rather than swapping its label (iOS's donate
 * sheet relabels it per amount — "Donate 10 hearts", "Pick an amount",
 * "Donated 10 hearts"; Android keeps the title fixed and lets the readout
 * above it carry the amount). Disabled stays a gradient at reduced opacity,
 * drawn with `ModulateAlpha` so the bloom isn't cut into a rectangle.
 *
 * @param bloom the lavender lift beneath; off inside a frosted card, where a
 *   second bloom gathers into a smudge.
 * @param trailing optional content after the label (the cause bar's "12 left").
 */
@Composable
fun HeartCapsule(
  title: String,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
  enabled: Boolean = true,
  bloom: Boolean = true,
  compact: Boolean = false,
  accessibilityLabel: String? = null,
  trailing: (@Composable RowScope.() -> Unit)? = null,
) {
  val alpha by animateFloatAsState(
    targetValue = if (enabled) 1f else DISABLED_ALPHA,
    animationSpec = settle(),
    label = "heart-capsule-alpha",
  )
  val shape = RoundedCornerShape(percent = 50)
  Row(
    modifier
      .fillMaxWidth()
      .graphicsLayer {
        this.alpha = alpha
        compositingStrategy = CompositingStrategy.ModulateAlpha
      }
      .softPress()
      .then(
        if (bloom) {
          Modifier.dropShadow(
            shape = shape,
            shadow = Shadow(
              radius = BLOOM_RADIUS,
              color = Color.lavenderMist.copy(alpha = BLOOM_ALPHA),
              offset = DpOffset(0.dp, BLOOM_OFFSET_Y),
            ),
          )
        } else {
          Modifier
        },
      )
      .background(Brush.horizontalGradient(listOf(Color.lavenderMist, Color.blushPowder)), shape)
      .clickable(
        enabled = enabled,
        role = Role.Button,
        interactionSource = null,
        indication = null,
        onClick = onClick,
      )
      // One node for TalkBack, carrying the label, the role and — when there
      // is nothing to commit — the disabled state, so a dimmed capsule reads
      // "Button, disabled" rather than an action-sounding label. A label
      // replaces the children outright: merged, the label landed on a child
      // node that still reported itself enabled (QA rounds 1–2, B19). With a
      // trailing slot the children stay merged in, so its words are read.
      .then(
        if (accessibilityLabel != null && trailing == null) {
          Modifier.clearAndSetSemantics {
            contentDescription = accessibilityLabel
            role = Role.Button
            if (enabled) this.onClick(label = null) { onClick(); true } else disabled()
          }
        } else {
          Modifier.semantics(mergeDescendants = true) {
            role = Role.Button
            if (!enabled) disabled()
            if (accessibilityLabel != null) contentDescription = accessibilityLabel
          }
        },
      )
      .padding(
        horizontal = if (compact) 16.dp else 22.dp,
        vertical = if (compact) 13.dp else 16.dp,
      ),
    horizontalArrangement = Arrangement.spacedBy(if (compact) 8.dp else 10.dp, Alignment.CenterHorizontally),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(
      imageVector = CompassionIcons.HeartFill,
      contentDescription = null,
      tint = Color.White,
      modifier = Modifier.size(if (compact) 15.dp else 17.dp),
    )
    Text(
      text = title,
      style = DeepType.sectionTitle,
      color = Color.White,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
      modifier = if (trailing != null) Modifier.weight(1f) else Modifier,
    )
    trailing?.invoke(this)
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Heart capsule")
@Composable
private fun HeartCapsulePreview() {
  Box(Modifier.fillMaxSize().background(Color.moonCream)) {
    AtmosphereBackground(animated = false)
    Column(Modifier.padding(Dp.edge), verticalArrangement = Arrangement.spacedBy(24.dp)) {
      HeartCapsule(title = "Donate hearts", onClick = {})
      HeartCapsule(title = "Donate hearts", onClick = {}, enabled = false)
      HeartCapsule(title = "Donate hearts", onClick = {}, bloom = false, compact = true)
      HeartCapsule(title = "Send a heart", onClick = {}) {
        Text("2,450 left", style = DeepType.caption, color = Color.White.copy(alpha = 0.85f))
      }
    }
  }
}
