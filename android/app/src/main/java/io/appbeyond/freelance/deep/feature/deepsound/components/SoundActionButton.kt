package io.appbeyond.freelance.deep.feature.deepsound.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

/** iOS's `RoundedRectangle(cornerRadius: 16)`. */
private val BUTTON_RADIUS = 16.dp

/** iOS's `.padding(.vertical, 13)`. */
private val BUTTON_PADDING_VERTICAL = 13.dp

/**
 * The glyph — iOS sizes it via `.font(.system(.subheadline, weight: .semibold))`, a
 * system-relative size with no fixed pt to cite; this is a fixed local approximation.
 */
private val GLYPH_SIZE = 16.dp

/**
 * The material stand-in, as in `frostedCard`: a translucent moonCream base for
 * iOS's `.ultraThinMaterial`, under the same white 0.55 wash iOS lays on top.
 */
private const val BASE_ALPHA = 0.6f
private const val WASH_ALPHA = 0.55f
private const val BORDER_ALPHA = 0.45f
private val BORDER_WIDTH = 0.5.dp

/**
 * The Play / Shuffle pair that opens a listening surface — a frosted, softly
 * pressed panel button, sized to share a row. Lives here rather than inside
 * one screen because a collection and a playlist start the same way.
 *
 * Ported from Deep/Deep/Features/DeepSound/Components/SoundActionButton.swift.
 * It fills the width it is given; give each of a pair `Modifier.weight(1f)`.
 * No shadow, like the original — it is a quiet control, not a card.
 */
@Composable
fun SoundActionButton(
  title: String,
  icon: ImageVector,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val shape = RoundedCornerShape(BUTTON_RADIUS)

  Row(
    modifier
      .fillMaxWidth()
      .softPress()
      .clip(shape)
      .background(Color.moonCream.copy(alpha = BASE_ALPHA))
      .background(Color.White.copy(alpha = WASH_ALPHA))
      .border(BORDER_WIDTH, Color.White.copy(alpha = BORDER_ALPHA), shape)
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        role = Role.Button,
        onClick = onClick,
      )
      .padding(vertical = BUTTON_PADDING_VERTICAL),
    horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(icon, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(GLYPH_SIZE))
    Text(title, style = DeepType.bodyMedium, color = Color.deepPlum, maxLines = 1)
  }
}

@Preview(showBackground = true, name = "Sound actions")
@Composable
private fun SoundActionButtonPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream), contentAlignment = Alignment.Center) {
      AtmosphereBackground()
      Row(
        Modifier.padding(horizontal = Dp.edge),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
      ) {
        SoundActionButton("Play", SoundIcons.Play, onClick = {}, modifier = Modifier.weight(1f))
        SoundActionButton("Shuffle", SoundIcons.Shuffle, onClick = {}, modifier = Modifier.weight(1f))
      }
    }
  }
}
