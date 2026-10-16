package io.appbeyond.freelance.deep.feature.compassion.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.shared.components.RollingText
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey

/** Fixed-width digits, so a rolling figure never jitters sideways. */
private const val TABULAR_FIGURES = "tnum"

/** A card fact's figure — iOS's `caption.weight(.semibold)` in deepPlum, tabular. */
internal val FactFigureStyle = DeepType.caption.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = TABULAR_FIGURES)

/** The words beside a figure — caption in driftGrey. */
internal val FactWordsStyle = DeepType.caption.copy(fontFeatureSettings = TABULAR_FIGURES)

/** A pebble's medium-weight figure line — iOS's `caption.weight(.medium)`. */
internal val FactMediumStyle = DeepType.caption.copy(fontWeight = FontWeight.Medium, fontFeatureSettings = TABULAR_FIGURES)

/**
 * One card fact in the house grammar: a small glyph, then a bold plum figure
 * rolling as it changes, then its words in grey — "318 given".
 *
 * @param figure null draws the words alone ("today is full").
 */
@Composable
internal fun CardFact(
  glyph: ImageVector,
  glyphSize: Dp,
  glyphTint: Color,
  figure: String?,
  value: Float,
  words: String,
  modifier: Modifier = Modifier,
) {
  Row(
    modifier,
    horizontalArrangement = Arrangement.spacedBy(5.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(glyph, contentDescription = null, tint = glyphTint, modifier = Modifier.size(glyphSize))
    Row(verticalAlignment = Alignment.CenterVertically) {
      if (figure != null) {
        RollingText(text = figure, value = value, style = FactFigureStyle, color = Color.deepPlum)
      }
      Text(text = words, style = FactWordsStyle, color = Color.driftGrey, maxLines = 1)
    }
  }
}
