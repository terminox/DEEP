package io.appbeyond.freelance.deep.feature.globalpause.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.globalpause.model.Continent
import io.appbeyond.freelance.deep.feature.globalpause.model.ContinentPresence
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.nightHorizon
import java.text.NumberFormat

/**
 * Where the world is pausing, named beneath the globe: one row, west to east,
 * each continent a count over its name. No glyph, no panel, no rule — on this
 * screen the numbers *are* the lights.
 *
 * The order is fixed, never ranked: the row is a map, not a leaderboard, and
 * columns that reorder while someone is meditating are movement for nothing.
 * Columns take their natural width and share what's left between them, so a
 * two-continent early session centres itself instead of stretching.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Components/ContinentLights.swift.
 */
@Composable
fun ContinentLights(presences: List<ContinentPresence>, modifier: Modifier = Modifier) {
  val reduceMotion = rememberReduceMotion()
  val format = NumberFormat.getIntegerInstance(LocalConfiguration.current.locales[0])
  val spokenParts = presences.map { presence ->
    stringResource(R.string.pause_continent_count_a11y, format.format(presence.count), spokenName(presence.continent))
  }
  val spoken = if (spokenParts.isEmpty()) "" else stringResource(R.string.pause_continents_a11y, spokenParts.joinToString(", "))

  Row(
    modifier
      .fillMaxWidth()
      .clearAndSetSemantics { contentDescription = spoken },
    horizontalArrangement = Arrangement.SpaceEvenly,
    verticalAlignment = Alignment.Top,
  ) {
    for (continent in Continent.entries) {
      val presence = presences.firstOrNull { it.continent == continent }
      // In on a bloom, out on an exhale. Reduce motion keeps the fade alone.
      AnimatedVisibility(
        visible = presence != null,
        enter = if (reduceMotion) fadeIn(bloom()) else fadeIn(bloom()) + scaleIn(bloom(), initialScale = 0.92f),
        exit = fadeOut(exhale()),
      ) {
        Column(
          Modifier.padding(horizontal = 4.dp),
          horizontalAlignment = Alignment.CenterHorizontally,
          verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
          Text(
            format.format(presence?.count ?: 0),
            style = DeepType.caption,
            // Dimmer than the headline count above — this row answers a
            // question the headline has already asked.
            color = Color.moonCream.copy(alpha = 0.62f),
            maxLines = 1,
          )
          Text(
            displayName(continent).uppercase(LocalConfiguration.current.locales[0]),
            style = DeepType.micro,
            color = Color.moonCream.copy(alpha = 0.38f),
            maxLines = 1,
            textAlign = TextAlign.Center,
          )
        }
      }
    }
  }
}

/** The name under the count, in the member's language. */
@Composable
fun displayName(continent: Continent): String = stringResource(
  when (continent) {
    Continent.Americas -> R.string.pause_continent_americas
    Continent.Europe -> R.string.pause_continent_europe
    Continent.Africa -> R.string.pause_continent_africa
    Continent.Asia -> R.string.pause_continent_asia
    Continent.Oceania -> R.string.pause_continent_oceania
    Continent.Antarctica -> R.string.pause_continent_antarctica
  },
)

/** The name inside a sentence — "1,842 in the Americas". */
@Composable
private fun spokenName(continent: Continent): String =
  if (continent == Continent.Americas) stringResource(R.string.pause_continent_americas_spoken) else displayName(continent)

@Preview(name = "The world")
@Composable
private fun ContinentLightsPreview() {
  DeepTheme {
    Box(Modifier.background(Color.nightHorizon).padding(vertical = 24.dp, horizontal = 12.dp)) {
      ContinentLights(
        ContinentPresence.row(mapOf("AS" to 1842, "EU" to 1106, "NA" to 604, "SA" to 199, "AF" to 291, "OC" to 176)),
      )
    }
  }
}

@Preview(name = "Early — two continents lit")
@Composable
private fun ContinentLightsEarlyPreview() {
  DeepTheme {
    Box(Modifier.background(Color.nightHorizon).padding(vertical = 24.dp, horizontal = 12.dp)) {
      ContinentLights(ContinentPresence.row(mapOf("AS" to 12, "EU" to 3)))
    }
  }
}
