package io.appbeyond.freelance.deep.feature.compassion.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.CompassionIcons
import io.appbeyond.freelance.deep.feature.compassion.FieldReport
import io.appbeyond.freelance.deep.feature.compassion.rememberCompassionContent
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.SectionHeader
import io.appbeyond.freelance.deep.shared.localization.AppFormat
import io.appbeyond.freelance.deep.shared.localization.rememberAppLocale
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream

/**
 * The "from the field" feed — recent real-world outcomes reported back, so
 * members see what their hearts set in motion. A chronology read top to
 * bottom rather than a shelf of parallel choices, so each dispatch gets its
 * own full-width row.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/FieldReportsSection.swift.
 */
@Composable
fun FieldReportsSection(reports: List<FieldReport>, modifier: Modifier = Modifier) {
  Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
    SectionHeader(title = stringResource(R.string.compassion_from_the_field))
    Column(
      Modifier.fillMaxWidth().padding(horizontal = Dp.edge),
      verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
      reports.forEach { FieldReportRow(it) }
    }
  }
}

/**
 * One dispatch from the field — something that came *back* from a cause, not
 * something to go into. Non-interactive: no button, no chevron. A plain,
 * untinted card: `frostedCard(tint)` blooms from the leading edge and would
 * pool entirely under the thumb at full width.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/FieldReportRow.swift.
 */
@Composable
fun FieldReportRow(report: FieldReport, modifier: Modifier = Modifier) {
  val locale = rememberAppLocale()
  Row(
    modifier
      .fillMaxWidth()
      .frostedCard()
      .padding(14.dp)
      .semantics(mergeDescendants = true) {},
    horizontalArrangement = Arrangement.spacedBy(14.dp),
  ) {
    CompassionMotif(symbol = report.symbol, palette = report.palette, modifier = Modifier.size(60.dp))

    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
      Text(report.causeName.uppercase(locale), style = DeepType.micro, color = Color.driftGrey)
      Text(
        text = report.title,
        style = DeepType.body.copy(fontWeight = FontWeight.SemiBold),
        color = Color.deepPlum,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
      )
      Text(
        text = report.blurb,
        style = DeepType.caption,
        color = Color.driftGrey,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
      )
      // Place at one end, time at the other — held apart by the gap, not a mark.
      Row(
        Modifier.fillMaxWidth().padding(top = 3.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
      ) {
        Row(
          Modifier.weight(1f),
          horizontalArrangement = Arrangement.spacedBy(4.dp),
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Icon(CompassionIcons.MappinAndEllipse, contentDescription = null, tint = Color.driftGrey, modifier = Modifier.size(13.dp))
          Text(report.location, style = DeepType.caption, color = Color.driftGrey, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Text(AppFormat.daysAgo(report.daysAgo, locale), style = DeepType.caption, color = Color.driftGrey, maxLines = 1)
      }
    }
  }
}

@Preview(showBackground = true, name = "Field reports")
@Composable
private fun FieldReportsSectionPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      FieldReportsSection(rememberCompassionContent().reports, Modifier.padding(vertical = 16.dp))
    }
  }
}
