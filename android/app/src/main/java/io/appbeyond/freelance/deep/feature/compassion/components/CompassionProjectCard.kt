package io.appbeyond.freelance.deep.feature.compassion.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.CompassionIcons
import io.appbeyond.freelance.deep.feature.compassion.CompassionProject
import io.appbeyond.freelance.deep.feature.compassion.model.CompassionCatalog
import io.appbeyond.freelance.deep.feature.compassion.rememberCompassionContent
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.CompassionRing
import io.appbeyond.freelance.deep.shared.components.HeartBurst
import io.appbeyond.freelance.deep.shared.components.RingSegment
import io.appbeyond.freelance.deep.shared.components.RollingText
import io.appbeyond.freelance.deep.shared.localization.AppFormat
import io.appbeyond.freelance.deep.shared.localization.rememberAppLocale
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.softPress

private val MOTIF_FRAME = 68.dp
private val MOTIF_INSET = 9.dp
private val SEND_SIZE = 40.dp

/**
 * One initiative within a cause: what it does, how far along it is, and a
 * one-tap heart to back it. Sending updates the live ledger, so the count
 * climbs in place. Progress rides as an arc around the motif rather than a
 * bar beneath the text — the halo language again.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/CompassionProjectCard.swift.
 *
 * @param pooled this project's pooled hearts, from the ledger's pool.
 * @param onSend sends one heart to this project.
 */
@Composable
fun CompassionProjectCard(
  project: CompassionProject,
  pooled: Int,
  canGive: Boolean,
  onSend: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val locale = rememberAppLocale()
  val percent = Math.round(project.progress * 100)
  var burst by remember { mutableIntStateOf(0) }
  Row(
    modifier.fillMaxWidth().frostedCard().padding(16.dp),
    horizontalArrangement = Arrangement.spacedBy(14.dp),
  ) {
    val progressLabel = stringResource(R.string.compassion_project_progress, percent)
    CompassionRing(
      segments = listOf(RingSegment(share = project.progress, colors = project.palette.colors)),
      lineWidth = 5.dp,
      gap = 0f,
      modifier = Modifier.size(MOTIF_FRAME).clearAndSetSemantics { contentDescription = progressLabel },
    ) {
      CompassionMotif(
        symbol = project.symbol,
        palette = project.palette,
        cornerRadius = 14.dp,
        modifier = Modifier.padding(MOTIF_INSET).fillMaxSize(),
      )
    }

    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
      Text(project.title, style = DeepType.body.copy(fontWeight = FontWeight.SemiBold), color = Color.deepPlum)
      Text(project.blurb, style = DeepType.caption, color = Color.driftGrey)
      // Two facts held apart by space, not by a mark.
      Row(Modifier.padding(top = 2.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        ProjectFact(CompassionIcons.HeartFill, Color.blushPowder) {
          val figure = AppFormat.number(pooled, locale)
          RollingText(
            text = stringResource(R.string.compassion_project_hearts, figure),
            value = pooled.toFloat(),
            style = FactMediumStyle,
            color = Color.driftGrey,
          )
        }
        ProjectFact(CompassionIcons.Target, Color.lavenderMist) {
          Text(stringResource(R.string.compassion_project_funded, percent), style = FactMediumStyle, color = Color.driftGrey)
        }
      }
    }

    HeartBurst(trigger = burst) {
      SendHeartButton(
        canGive = canGive,
        label = stringResource(R.string.compassion_send_a_heart_to, project.title),
        onClick = {
          onSend()
          burst += 1
        },
      )
    }
  }
}

@Composable
private fun ProjectFact(glyph: ImageVector, tint: Color, label: @Composable () -> Unit) {
  Row(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
    Icon(glyph, contentDescription = null, tint = tint, modifier = Modifier.size(10.dp))
    label()
  }
}

/** The round one-tap heart; greyed and inert once nothing is left to give. */
@Composable
private fun SendHeartButton(canGive: Boolean, label: String, onClick: () -> Unit) {
  Box(
    Modifier
      .size(SEND_SIZE)
      .softPress()
      .clip(CircleShape)
      .background(if (canGive) Color.blushPowder.copy(alpha = 0.22f) else Color.White.copy(alpha = 0.4f))
      .border(0.5.dp, Color.White.copy(alpha = 0.5f), CircleShape)
      .clickable(
        enabled = canGive,
        role = Role.Button,
        onClickLabel = label,
        interactionSource = null,
        indication = null,
        onClick = onClick,
      )
      .clearAndSetSemantics { contentDescription = label },
    contentAlignment = Alignment.Center,
  ) {
    Icon(
      CompassionIcons.HeartFill,
      contentDescription = null,
      tint = if (canGive) Color.blushPowder else Color.driftGrey.copy(alpha = 0.5f),
      modifier = Modifier.size(17.dp),
    )
  }
}

@Preview(showBackground = true, name = "Project cards")
@Composable
private fun CompassionProjectCardPreview() {
  DeepTheme {
    val cause = rememberCompassionContent().cause("healthcare")!!
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      Column(Modifier.padding(Dp.edge), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        cause.projects.forEachIndexed { index, project ->
          CompassionProjectCard(
            project = project,
            pooled = CompassionCatalog.launchPool.projectHearts(project.id),
            canGive = index != 2,
            onSend = {},
          )
        }
      }
    }
  }
}
