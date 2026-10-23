package io.appbeyond.freelance.deep.feature.compassion.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.feature.compassion.CompassionIcons
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.pebble

/** One headline figure shown in a stat cluster. */
@Immutable
data class ImpactStat(val label: String, val value: String, val symbol: ImageVector)

/**
 * A group of headline figures on a frosted surface. Each figure sits on its
 * own inset tonal panel, so the group reads by *surface* rather than by the
 * hairline rules a stat row usually leans on.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/ImpactPebbles.swift.
 * The row is measured at its intrinsic height so a two-line label never
 * leaves a ragged row.
 */
@Composable
fun ImpactPebbles(stats: List<ImpactStat>, modifier: Modifier = Modifier) {
  Row(
    modifier
      .fillMaxWidth()
      .frostedCard()
      .padding(10.dp)
      .height(IntrinsicSize.Max),
    horizontalArrangement = Arrangement.spacedBy(8.dp),
  ) {
    stats.forEach { stat -> StatPebble(stat, Modifier.weight(1f).fillMaxHeight()) }
  }
}

/** One figure on its own panel: glyph, value, label. */
@Composable
private fun StatPebble(stat: ImpactStat, modifier: Modifier = Modifier) {
  Column(
    modifier
      .pebble()
      .padding(vertical = 16.dp, horizontal = 6.dp)
      .semantics(mergeDescendants = true) {},
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(6.dp),
  ) {
    Icon(stat.symbol, contentDescription = null, tint = Color.lavenderMist, modifier = Modifier.size(16.dp))
    Text(stat.value, style = DeepType.counter.copy(fontFeatureSettings = "tnum"), color = Color.deepPlum, maxLines = 1)
    Text(stat.label, style = DeepType.caption, color = Color.driftGrey, textAlign = TextAlign.Center)
  }
}

@Preview(showBackground = true, name = "Impact pebbles")
@Composable
private fun ImpactPebblesPreview() {
  Box(Modifier.fillMaxSize().background(Color.moonCream)) {
    AtmosphereBackground(animated = false)
    ImpactPebbles(
      stats = listOf(
        ImpactStat("Hearts pooled", "16.2K", CompassionIcons.HeartFill),
        ImpactStat("People reached", "96K", CompassionIcons.PersonTwoFill),
        ImpactStat("Share of giving", "24%", CompassionIcons.ChartPieFill),
      ),
      modifier = Modifier.padding(Dp.edge),
    )
  }
}
