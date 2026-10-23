package io.appbeyond.freelance.deep.feature.compassion.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.CompassionIcons
import io.appbeyond.freelance.deep.feature.compassion.store.HeartLedger
import io.appbeyond.freelance.deep.shared.components.ArtworkPalette
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.CompassionRing
import io.appbeyond.freelance.deep.shared.components.RingSegment
import io.appbeyond.freelance.deep.shared.localization.AppFormat
import io.appbeyond.freelance.deep.shared.localization.rememberAppLocale
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.duskRose
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import java.time.Clock
import java.time.ZoneId

// MARK: - Constants

private val CARD_PADDING = 20.dp
private val ROW_SPACING = 16.dp
private val COLUMN_SPACING = 5.dp

/** The halo — iOS's 80pt portrait, 7pt gap, 5pt ring. */
private val PORTRAIT = 80.dp
private val RING_GAP = 7.dp
private val RING_WIDTH = 5.dp
private val HALO = PORTRAIT + (RING_GAP + RING_WIDTH) * 2

/** A closed day settles into a glow — iOS's `shadow(blushPowder 0.55, radius: 7)`. */
private const val FULL_GLOW_ALPHA = 0.55f
private val FULL_GLOW_RADIUS = 7.dp

/** The today fact's heart — iOS's `duskRose.opacity(0.75)`. */
private const val TODAY_GLYPH_ALPHA = 0.75f

// MARK: - Card

/**
 * What you hold, held in the day that gave it — the Compassion tab's opening
 * card, built as the sibling of `GardenGrowthCard`'s plant row: a portrait
 * inside a halo, beside its name and the two facts that matter.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/CompassionPortfolioCard.swift.
 * The halo is today: a day hands over at most [HeartLedger.dailyEarnCeiling]
 * hearts, and the ring closes as they arrive. The pooled allocation ring lives
 * in [CommunityPoolCard] below — *mine*, then *ours*. Nothing given yet stays
 * unsaid; a first day shouldn't open with a zero.
 */
@Composable
fun CompassionPortfolioCard(
  ledger: HeartLedger,
  modifier: Modifier = Modifier,
) {
  val state by ledger.state.collectAsStateWithLifecycle()
  val locale = rememberAppLocale()
  val today = ledger.today()
  val earnedToday = state.heartsEarnedOn(today)
  val isFull = state.isFullOn(today)
  val ceiling = HeartLedger.dailyEarnCeiling

  val headline = when {
    state.canGive -> stringResource(R.string.compassion_to_give, AppFormat.number(state.balance, locale))
    state.heartsGiven > 0 -> stringResource(R.string.compassion_all_given)
    else -> stringResource(R.string.compassion_no_hearts_yet)
  }

  val summary = listOfNotNull(
    if (state.canGive) {
      pluralStringResource(R.plurals.compassion_summary_can_give, state.balance, state.balance)
    } else {
      stringResource(R.string.compassion_summary_none_left)
    },
    if (state.heartsGiven > 0) stringResource(R.string.compassion_summary_given, state.heartsGiven) else null,
    if (isFull) {
      pluralStringResource(R.plurals.compassion_summary_today_full, ceiling, ceiling)
    } else {
      pluralStringResource(R.plurals.compassion_summary_today, ceiling, earnedToday, ceiling)
    },
  ).joinToString(". ")

  Row(
    modifier
      .fillMaxWidth()
      .frostedCard()
      .padding(CARD_PADDING)
      .clearAndSetSemantics { contentDescription = summary },
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    HeartDayHalo(progress = earnedToday.toFloat() / ceiling, isFull = isFull)

    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(COLUMN_SPACING)) {
      Text(
        text = stringResource(R.string.compassion_my_hearts),
        style = DeepType.micro,
        color = Color.driftGrey,
      )
      // Words as well as a figure, and free to wrap, so it crossfades rather
      // than rolling.
      AnimatedContent(
        targetState = headline,
        transitionSpec = { fadeIn(exhale()) togetherWith fadeOut(exhale()) },
        label = "portfolio-headline",
      ) { line ->
        Text(text = line, style = DeepType.displayTitle, color = Color.deepPlum)
      }
      // One fact per line rather than a wrapping row: a layout that decides
      // differently between launches is worse than one that always stacks.
      if (state.heartsGiven > 0) {
        CardFact(
          glyph = CompassionIcons.HeartFill,
          glyphSize = 10.dp,
          glyphTint = Color.blushPowder,
          figure = AppFormat.number(state.heartsGiven, locale),
          value = state.heartsGiven.toFloat(),
          words = stringResource(R.string.compassion_given_suffix),
        )
      }
      if (isFull) {
        CardFact(
          glyph = CompassionIcons.HeartFill,
          glyphSize = 11.dp,
          glyphTint = Color.duskRose.copy(alpha = TODAY_GLYPH_ALPHA),
          figure = null,
          value = 0f,
          words = stringResource(R.string.compassion_today_full),
        )
      } else {
        CardFact(
          glyph = CompassionIcons.HeartFill,
          glyphSize = 11.dp,
          glyphTint = Color.duskRose.copy(alpha = TODAY_GLYPH_ALPHA),
          figure = AppFormat.number(earnedToday, locale),
          value = earnedToday.toFloat(),
          words = stringResource(R.string.compassion_today_suffix, ceiling),
        )
      }
    }
  }
}

/**
 * The member's hearts as a portrait inside the day's halo — the same
 * construction as the plant in its growth ring. A gradient motif rather than
 * a filled disc: the disc is this app's primary-action button, and this card
 * isn't tappable. `.dusk`, because blush-into-lilac greys out under the
 * artwork's plum vignette.
 */
@Composable
private fun HeartDayHalo(progress: Float, isFull: Boolean) {
  CompassionRing(
    segments = listOf(
      RingSegment(share = progress.coerceIn(0f, 1f), colors = listOf(Color.lavenderMist, Color.blushPowder)),
    ),
    lineWidth = RING_WIDTH,
    gap = 0f,
    glowColor = if (isFull) Color.blushPowder.copy(alpha = FULL_GLOW_ALPHA) else Color.Transparent,
    glowRadius = FULL_GLOW_RADIUS,
    modifier = Modifier.size(HALO),
  ) {
    CompassionMotif(
      symbol = CompassionIcons.HeartFill,
      palette = ArtworkPalette.Dusk,
      cornerRadius = Dp.chip,
      symbolScale = 0.4f,
      modifier = Modifier.padding(RING_GAP + RING_WIDTH).fillMaxSize(),
    )
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Portfolio card")
@Composable
private fun CompassionPortfolioCardPreview() {
  val clock = Clock.systemDefaultZone()
  val zone = ZoneId.systemDefault()
  val ledgers = remember {
    listOf(HeartLedger.sample(clock, zone), HeartLedger.fresh(clock, zone), HeartLedger.spent(clock, zone))
  }
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      Column(Modifier.padding(Dp.edge), verticalArrangement = Arrangement.spacedBy(Dp.rhythm)) {
        ledgers.forEach { CompassionPortfolioCard(it) }
      }
    }
  }
}

@Preview(showBackground = true, name = "Portfolio card — large type", fontScale = 1.6f)
@Composable
private fun CompassionPortfolioCardLargeTypePreview() {
  val ledger = remember { HeartLedger.sample(Clock.systemDefaultZone(), ZoneId.systemDefault()) }
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      CompassionPortfolioCard(ledger, Modifier.padding(Dp.edge).width(335.dp))
    }
  }
}
