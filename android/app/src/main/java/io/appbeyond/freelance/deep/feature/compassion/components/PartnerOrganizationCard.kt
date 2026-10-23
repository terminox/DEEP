package io.appbeyond.freelance.deep.feature.compassion.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.appshell.DeepIcons
import io.appbeyond.freelance.deep.feature.compassion.CompassionIcons
import io.appbeyond.freelance.deep.feature.compassion.CompassionPartner
import io.appbeyond.freelance.deep.feature.compassion.rememberCompassionContent
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.softPress

/** The meta chips' wash — iOS's `lavenderMist.opacity(0.12)`. */
private const val CHIP_FILL_ALPHA = 0.12f

/**
 * The real-world organisation a cause's donations flow to — who does the work
 * and where, so the promise behind a heart is concrete.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/PartnerOrganizationCard.swift.
 * The website is styled as a link, so it behaves as one: it opens in the
 * browser.
 */
@Composable
fun PartnerOrganizationCard(partner: CompassionPartner, modifier: Modifier = Modifier) {
  val uriHandler = LocalUriHandler.current
  val visit = stringResource(R.string.compassion_partner_visit, partner.name)
  Column(
    modifier.fillMaxWidth().frostedCard().padding(18.dp),
    verticalArrangement = Arrangement.spacedBy(14.dp),
  ) {
    Text(stringResource(R.string.compassion_partner_organisation), style = DeepType.micro, color = Color.lavenderMist)

    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
      Box(
        Modifier
          .size(52.dp)
          .background(
            Brush.linearGradient(listOf(Color.lavenderMist, Color.blushPowder)),
            RoundedCornerShape(14.dp),
          ),
        contentAlignment = Alignment.Center,
      ) {
        Icon(partner.symbol, contentDescription = null, tint = Color.White, modifier = Modifier.size(24.dp))
      }
      Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(partner.name, style = DeepType.sectionTitle, color = Color.deepPlum)
        Text(partner.blurb, style = DeepType.caption, color = Color.driftGrey)
      }
    }

    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
      MetaChip(DeepIcons.Globe, partner.scope)
      MetaChip(CompassionIcons.Calendar, stringResource(R.string.compassion_partner_since, partner.since.toString()))
    }

    Row(
      Modifier
        .softPress()
        .clickable(
          role = Role.Button,
          onClickLabel = visit,
          interactionSource = null,
          indication = null,
        ) { uriHandler.openUri("https://${partner.website}") }
        .semantics { contentDescription = visit },
      horizontalArrangement = Arrangement.spacedBy(6.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Icon(CompassionIcons.Link, contentDescription = null, tint = Color.lavenderMist, modifier = Modifier.size(11.dp))
      Text(
        partner.website,
        style = FactMediumStyle,
        color = Color.lavenderMist,
        maxLines = 1,
        overflow = TextOverflow.MiddleEllipsis,
      )
    }
  }
}

@Composable
private fun MetaChip(glyph: ImageVector, text: String) {
  Row(
    Modifier
      .background(Color.lavenderMist.copy(alpha = CHIP_FILL_ALPHA), RoundedCornerShape(Dp.chip))
      .padding(horizontal = 10.dp, vertical = 6.dp),
    horizontalArrangement = Arrangement.spacedBy(5.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(glyph, contentDescription = null, tint = Color.driftGrey, modifier = Modifier.size(11.dp))
    Text(text, style = FactMediumStyle, color = Color.driftGrey, maxLines = 1)
  }
}

@Preview(showBackground = true, name = "Partner organisation")
@Composable
private fun PartnerOrganizationCardPreview() {
  DeepTheme {
    val partner = rememberCompassionContent().cause("healthcare")!!.partner
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      PartnerOrganizationCard(partner, Modifier.padding(Dp.edge))
    }
  }
}
