package io.appbeyond.freelance.deep.shared.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

private val CHIP_PADDING_HORIZONTAL = 14.dp
private val CHIP_PADDING_VERTICAL = 9.dp
private val CHIP_BORDER_WIDTH = 0.5.dp
private const val UNSELECTED_FILL_ALPHA = 0.75f
private const val UNSELECTED_BORDER_ALPHA = 0.6f
private const val UNSELECTED_TEXT_ALPHA = 0.85f

/** The selected chip's glow — iOS's `shadow(radius: 10, x: 0, y: 4)`. */
private const val GLOW_ALPHA = 0.32f
private val GLOW_RADIUS = 10.dp
private val GLOW_OFFSET_Y = 4.dp

private val TAG_PADDING_HORIZONTAL = 10.dp
private val TAG_PADDING_VERTICAL = 5.dp
private val TAG_BORDER_WIDTH = 0.5.dp
private const val TAG_FILL_ALPHA = 0.6f
private const val TAG_BORDER_ALPHA = 0.7f
private const val TAG_TEXT_ALPHA = 0.6f

// MARK: - DeepChip

/**
 * A selectable word — the app's one chip. Unselected it is a soft white
 * capsule on the atmosphere; selected it fills with the lavender→blush
 * gradient and lifts on its own glow.
 *
 * Ported from Deep/Deep/Shared/Components/DeepChip.swift. One implementation
 * on purpose: iOS notes the intention row and the mood row used to each carry
 * their own copy of this and had already drifted apart.
 */
@Composable
fun DeepChip(
  label: String,
  isSelected: Boolean,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val shape = RoundedCornerShape(Dp.chip)

  Box(
    modifier = modifier
      .then(if (isSelected) Modifier.chipGlow() else Modifier)
      .clip(shape)
      .then(
        if (isSelected) {
          Modifier.background(Brush.horizontalGradient(listOf(Color.lavenderMist, Color.blushPowder)))
        } else {
          Modifier
            .background(Color.White.copy(alpha = UNSELECTED_FILL_ALPHA))
            .border(CHIP_BORDER_WIDTH, Color.White.copy(alpha = UNSELECTED_BORDER_ALPHA), shape)
        },
      )
      .softPress()
      .selectable(selected = isSelected, onClick = onClick)
      .padding(horizontal = CHIP_PADDING_HORIZONTAL, vertical = CHIP_PADDING_VERTICAL),
  ) {
    Text(
      text = label,
      style = if (isSelected) DeepType.bodyMedium else DeepType.body,
      color = if (isSelected) Color.White else Color.deepPlum.copy(alpha = UNSELECTED_TEXT_ALPHA),
    )
  }
}

/** The soft lavender glow a selected chip lifts on. Drawn behind the fill, never clipped by it. */
private fun Modifier.chipGlow(): Modifier = dropShadow(
  shape = RoundedCornerShape(Dp.chip),
  shadow = Shadow(
    radius = GLOW_RADIUS,
    color = Color.lavenderMist.copy(alpha = GLOW_ALPHA),
    offset = DpOffset(0.dp, GLOW_OFFSET_Y),
  ),
)

// MARK: - DeepTagLabel

/**
 * The same word at rest — how a chosen tag reads once it is no longer a
 * control, e.g. on a peace-message card in the feed.
 */
@Composable
fun DeepTagLabel(label: String, modifier: Modifier = Modifier) {
  val shape = RoundedCornerShape(Dp.chip)

  Box(
    modifier = modifier
      .clip(shape)
      .background(Color.White.copy(alpha = TAG_FILL_ALPHA))
      .border(TAG_BORDER_WIDTH, Color.White.copy(alpha = TAG_BORDER_ALPHA), shape)
      .padding(horizontal = TAG_PADDING_HORIZONTAL, vertical = TAG_PADDING_VERTICAL),
  ) {
    Text(
      text = label,
      style = DeepType.micro,
      color = Color.deepPlum.copy(alpha = TAG_TEXT_ALPHA),
    )
  }
}

// MARK: - Preview

@Preview(showBackground = true, name = "Chips")
@Composable
private fun DeepChipPreview() {
  var selected by remember { mutableStateOf("Healing") }

  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground()
      Column(
        modifier = Modifier.padding(Dp.edge),
        verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
      ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
          listOf("Peace", "Healing", "Gratitude").forEach { label ->
            DeepChip(
              label = label,
              isSelected = selected == label,
              onClick = { selected = if (selected == label) "" else label },
            )
          }
        }
        DeepTagLabel(label = "Gratitude")
      }
    }
  }
}
