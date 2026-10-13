package io.appbeyond.freelance.deep.shared.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.appshell.DeepIcons
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.sunbeam
import java.text.NumberFormat

// MARK: - Constants

/** The sun glyph — iOS's 11pt semibold `sun.max.fill`. */
private val SUN_SIZE = 12.dp

/** Glyph-to-figure spacing — iOS's `HStack(spacing: 5)`. */
private val SUN_SPACING = 5.dp

/** Fixed-width digits, so a rolling figure never jitters sideways. */
private const val TABULAR_FIGURES = "tnum"

/** The figure: caption semibold in tabular digits. */
private val FIGURE_STYLE = DeepType.caption.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = TABULAR_FIGURES)

/** The words around the figure. */
private val WORDS_STYLE = DeepType.caption.copy(fontFeatureSettings = TABULAR_FIGURES)

// MARK: - Fact

/**
 * The garden's sunlight fact: the sun that introduces a sunlight figure, glyph
 * and figure sharing `sunbeam` so the pair reads as one mark.
 *
 * Only the figure takes the tint — the words around it stay grey, which keeps
 * the colour to a mark rather than a wash. Green stays the plant's own colour,
 * kept for the halo; the gold belongs to what fills it.
 *
 * Ported from Deep/Deep/Features/MindGarden/Components/SunlightFact.swift. This
 * overload is the bare shape; the two readings the app uses are below.
 */
@Composable
fun SunlightFact(
  modifier: Modifier = Modifier,
  label: @Composable RowScope.() -> Unit,
) {
  Row(
    modifier = modifier,
    horizontalArrangement = Arrangement.spacedBy(SUN_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(
      imageVector = DeepIcons.SunFill,
      contentDescription = null,
      tint = Color.sunbeam,
      modifier = Modifier.size(SUN_SIZE),
    )
    label()
  }
}

/**
 * The growth card's reading: how far the next form is, as sunlight banked over
 * goal — "240/700 to Mature Oak" — or "Fully grown" once there is no next form.
 * The banked figure rolls digit by digit as sunlight lands (iOS's
 * `.contentTransition(.numericText())`).
 *
 * Pass a null [goal] or [nextStageName] for the fully grown plant. The caller
 * owns the accessibility summary (the growth row speaks as one element), but
 * the fact still reads sensibly on its own.
 */
@Composable
fun SunlightFact(
  sunlight: Int,
  goal: Int?,
  nextStageName: String?,
  modifier: Modifier = Modifier,
) {
  SunlightFact(modifier) {
    if (goal == null || nextStageName == null) {
      Text(
        text = stringResource(R.string.sunlight_fact_fully_grown),
        style = DeepType.caption,
        color = Color.sunbeam,
      )
    } else {
      // One reading, "240/700 to Mature Oak": the figure and its goal sit flush,
      // so the sun's spacing must not fall between them too.
      Row(
        modifier = Modifier.weight(1f, fill = false),
        verticalAlignment = Alignment.CenterVertically,
      ) {
        RollingFigure(value = sunlight, style = FIGURE_STYLE, color = Color.sunbeam)
        Text(
          text = stringResource(R.string.sunlight_fact_to_next, formatFigure(goal), nextStageName),
          style = WORDS_STYLE,
          color = Color.driftGrey,
        )
      }
    }
  }
}

/** The picker's reading: what this plant has banked, full stop. */
@Composable
fun SunlightFact(
  sunlight: Int,
  modifier: Modifier = Modifier,
) {
  SunlightFact(modifier) {
    RollingFigure(value = sunlight, style = FIGURE_STYLE, color = Color.sunbeam)
  }
}

// MARK: - Rolling figure

/** A grouped integer rolling digit by digit — [RollingText] over [formatFigure]. */
@Composable
private fun RollingFigure(
  value: Int,
  style: TextStyle,
  color: Color,
  modifier: Modifier = Modifier,
) {
  RollingText(text = formatFigure(value), value = value.toFloat(), style = style, color = color, modifier = modifier)
}

/** The app locale's grouped integer — iOS's `.formatted()`. */
private fun formatFigure(value: Int): String = NumberFormat.getIntegerInstance().format(value)

// MARK: - Previews

@Preview(showBackground = true, name = "Sunlight fact")
@Composable
private fun SunlightFactPreview() {
  Box(Modifier.fillMaxSize().background(Color.moonCream)) {
    AtmosphereBackground(animated = false)
    Column(
      modifier = Modifier
        .padding(Dp.edge)
        .frostedCard()
        .padding(20.dp),
      verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
      // The growth card's reading: how far the next form is.
      SunlightFact(sunlight = 240, goal = 700, nextStageName = "Mature Oak")
      // A plant with no next form.
      SunlightFact(sunlight = 1_200, goal = null, nextStageName = null)
      // The picker's reading: what this plant has banked, full stop.
      SunlightFact(sunlight = 480)
    }
  }
}
