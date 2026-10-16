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
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.CompassionCause
import io.appbeyond.freelance.deep.feature.compassion.CompassionIcons
import io.appbeyond.freelance.deep.feature.compassion.rememberCompassionContent
import io.appbeyond.freelance.deep.feature.compassion.model.CompassionCatalog
import io.appbeyond.freelance.deep.feature.compassion.model.CompassionPool
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.CompassionRing
import io.appbeyond.freelance.deep.shared.components.RingSegment
import io.appbeyond.freelance.deep.shared.components.RollingText
import io.appbeyond.freelance.deep.shared.localization.AppFormat
import io.appbeyond.freelance.deep.shared.localization.rememberAppLocale
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.pebble

// MARK: - Constants

private val CARD_PADDING = 20.dp
private val CARD_SPACING = 14.dp

/** 140, not 116: the centre stack needs the room, and wider arcs tell causes apart. */
private val RING_SIZE = 140.dp
private val RING_WIDTH = 14.dp

private val LEGEND_SPACING = 10.dp
private val LEGEND_PADDING_HORIZONTAL = 14.dp
private val LEGEND_PADDING_VERTICAL = 12.dp
private val LEGEND_MARKER = 20.dp
private val LEGEND_SHARE_WIDTH = 40.dp

// MARK: - Card

/**
 * Where the community's pooled hearts have gone — the allocation ring given its
 * own card, with a legend that makes it readable rather than merely decorative.
 * Paired with [CompassionPortfolioCard] above it: "MY HEARTS", then "THE
 * COMMUNITY POOL" — *mine*, then *ours*.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/CommunityPoolCard.swift.
 * The legend iterates [causes] in their given order, never sorted by share —
 * the shelf below repeats the same glyphs in the same order. Each cause wears a
 * single palette, so an arc, its legend chip and its tile all say one colour.
 */
@Composable
fun CommunityPoolCard(
  causes: List<CompassionCause>,
  pool: CompassionPool,
  peopleReached: Int,
  modifier: Modifier = Modifier,
) {
  val locale = rememberAppLocale()
  Column(
    modifier
      .fillMaxWidth()
      .frostedCard()
      .padding(CARD_PADDING),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(CARD_SPACING),
  ) {
    Text(stringResource(R.string.compassion_community_pool), style = DeepType.micro, color = Color.driftGrey)

    PoolRing(causes, pool, Modifier.padding(bottom = 2.dp))

    Column(
      Modifier
        .fillMaxWidth()
        .pebble()
        .padding(horizontal = LEGEND_PADDING_HORIZONTAL, vertical = LEGEND_PADDING_VERTICAL),
      verticalArrangement = Arrangement.spacedBy(LEGEND_SPACING),
    ) {
      causes.forEach { cause -> LegendRow(cause, pool.shareOfGiving(cause.id)) }
    }

    Text(
      text = stringResource(
        R.string.compassion_people_reached_across,
        AppFormat.compact(peopleReached, locale),
        causes.size,
      ),
      style = DeepType.caption,
      color = Color.driftGrey,
      textAlign = TextAlign.Center,
    )
  }
}

/**
 * The arcs stay decorative — the legend is the accessible chart — but the
 * total is spoken nowhere else, and the heart above it can't be read aloud,
 * so the ring names it.
 */
@Composable
private fun PoolRing(causes: List<CompassionCause>, pool: CompassionPool, modifier: Modifier = Modifier) {
  val locale = rememberAppLocale()
  val pooled = pool.heartsPooled
  val label = stringResource(R.string.compassion_hearts_pooled)
  val spoken = AppFormat.number(pooled, locale)
  CompassionRing(
    segments = causes.map { RingSegment(share = pool.shareOfGiving(it.id), colors = it.palette.colors) },
    lineWidth = RING_WIDTH,
    modifier = modifier
      .size(RING_SIZE)
      .clearAndSetSemantics { contentDescription = "$label, $spoken" },
  ) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
      Icon(CompassionIcons.HeartFill, contentDescription = null, tint = Color.blushPowder, modifier = Modifier.size(15.dp))
      RollingText(
        text = AppFormat.compact(pooled, locale),
        value = pooled.toFloat(),
        style = DeepType.counter.copy(fontFeatureSettings = "tnum"),
        color = Color.deepPlum,
      )
    }
  }
}

@Composable
private fun LegendRow(cause: CompassionCause, share: Float) {
  val locale = rememberAppLocale()
  val percent = AppFormat.percent(share, locale)
  Row(
    Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
    horizontalArrangement = Arrangement.spacedBy(10.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    CompassionMotif(
      symbol = cause.symbol,
      palette = cause.palette,
      cornerRadius = Dp.chip,
      symbolScale = 0.46f,
      symbolOpacity = 0.95f,
      symbolShadow = false,
      bordered = false,
      modifier = Modifier.size(LEGEND_MARKER),
    )
    Text(
      text = cause.name,
      style = DeepType.body,
      color = Color.deepPlum,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
      modifier = Modifier.weight(1f),
    )
    Box(Modifier.width(LEGEND_SHARE_WIDTH), contentAlignment = Alignment.CenterEnd) {
      RollingText(text = percent, value = share, style = FactFigureStyle, color = Color.deepPlum)
    }
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Community pool")
@Composable
private fun CommunityPoolCardPreview() {
  DeepTheme {
    val content = rememberCompassionContent()
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      CommunityPoolCard(
        causes = content.causes,
        pool = remember { CompassionCatalog.launchPool },
        peopleReached = CompassionCatalog.peopleReached,
        modifier = Modifier.padding(Dp.edge),
      )
    }
  }
}
