package io.appbeyond.freelance.deep.feature.compassion.components

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.CompassionCause
import io.appbeyond.freelance.deep.feature.compassion.CompassionIcons
import io.appbeyond.freelance.deep.feature.compassion.model.CompassionPool
import io.appbeyond.freelance.deep.feature.compassion.rememberCompassionContent
import io.appbeyond.freelance.deep.feature.compassion.store.HeartLedger
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.RollingText
import io.appbeyond.freelance.deep.shared.components.SectionHeader
import io.appbeyond.freelance.deep.shared.localization.AppFormat
import io.appbeyond.freelance.deep.shared.localization.rememberAppLocale
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.pebble
import io.appbeyond.freelance.deep.theme.tile
import java.time.Clock
import java.time.ZoneId

// MARK: - Constants

private val TILE_WIDTH = 224.dp

/** How far a cause's name may shrink to stay on one line. */
private const val TITLE_MIN_SCALE = 0.75f

private val TITLE_SCALE_STEP = 0.25.sp
private val BANNER_HEIGHT = 132.dp
private val SHELF_SPACING = 16.dp

/**
 * The room each tile's bloom needs, given in full: `frostedCard`'s shadow is
 * lavenderMist 0.18, radius 24, y 12, so it reaches 12 above a card and 36
 * below. Anything less clips the plume off square along the scroll's edge.
 */
private val SHELF_PADDING_TOP = 14.dp
private val SHELF_PADDING_BOTTOM = 38.dp

// MARK: - Section

/**
 * The causes the community's hearts flow to, as a horizontal shelf. The
 * reach figure lives on [CommunityPoolCard] instead, so the same sentence
 * never appears twice within a thumb's scroll.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/CausesSection.swift.
 * A scrolling `Row` at intrinsic height rather than a `LazyRow`: five tiles,
 * and their heights have to level (iOS's `.fixedSize(vertical:)`).
 */
@Composable
fun CausesSection(
  causes: List<CompassionCause>,
  pool: CompassionPool,
  onDonate: (CompassionCause) -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
    SectionHeader(
      title = stringResource(R.string.compassion_causes_title),
      subtitle = stringResource(R.string.compassion_causes_subtitle),
    )
    Row(
      Modifier
        .horizontalScroll(rememberScrollState())
        .height(IntrinsicSize.Max)
        .padding(horizontal = Dp.edge)
        .padding(top = SHELF_PADDING_TOP, bottom = SHELF_PADDING_BOTTOM),
      horizontalArrangement = Arrangement.spacedBy(SHELF_SPACING),
    ) {
      causes.forEach { cause ->
        CategoryTile(
          cause = cause,
          pooled = pool.hearts(cause.id),
          share = pool.shareOfGiving(cause.id),
          onDonate = { onDonate(cause) },
          modifier = Modifier.fillMaxHeight(),
        )
      }
    }
  }
}

// MARK: - Tile

/**
 * A single cause in the shelf. The card wears a full-bleed motif banner of the
 * cause's own palette, so five causes read as five warmths rather than five
 * identical boxes.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/CategoryTile.swift.
 * The tile is where giving happens: what the cause is, what has flowed to it,
 * the share of DEEP's giving that follows, and the donate capsule. The card
 * body is not a button; only the capsule acts — and it stays live whatever the
 * balance, so the sheet (the one place that can also say what changes it) is
 * where a member learns there is nothing left to give yet.
 */
@Composable
fun CategoryTile(
  cause: CompassionCause,
  pooled: Int,
  share: Float,
  onDonate: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val locale = rememberAppLocale()
  Column(
    modifier
      .width(TILE_WIDTH)
      .frostedCard(tint = cause.palette.colors.first()),
  ) {
    // Unbordered: a bordered artwork clipped at its lower edge would draw a
    // straight white line across the card's waist — the rule this app never draws.
    CompassionMotif(
      symbol = cause.symbol,
      palette = cause.palette,
      cornerRadius = 0.dp,
      symbolScale = 0.46f,
      symbolOpacity = 0.9f,
      bordered = false,
      modifier = Modifier
        .fillMaxWidth()
        .height(BANNER_HEIGHT)
        .clip(RoundedCornerShape(topStart = Dp.card, topEnd = Dp.card)),
    )

    Column(
      Modifier
        .fillMaxWidth()
        .weight(1f)
        .padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 14.dp),
      verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
      // One line, shrinking before it clips — iOS's `.minimumScaleFactor`. The
      // Thai "สันติภาพและความเป็นอยู่ที่ดี" is wider than the tile at full size.
      BasicText(
        text = cause.name,
        style = DeepType.sectionTitle.copy(color = Color.deepPlum),
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        autoSize = TextAutoSize.StepBased(
          minFontSize = DeepType.sectionTitle.fontSize * TITLE_MIN_SCALE,
          maxFontSize = DeepType.sectionTitle.fontSize,
          stepSize = TITLE_SCALE_STEP,
        ),
      )
      // Two lines reserved, so the five cards level whichever taglines wrap.
      Text(
        text = cause.tagline,
        style = DeepType.caption,
        color = Color.driftGrey,
        minLines = 2,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
      )

      TileFacts(
        pooled = AppFormat.compact(pooled, locale),
        pooledValue = pooled,
        share = share,
        spoken = stringResource(
          R.string.compassion_tile_facts,
          AppFormat.number(pooled, locale),
          Math.round(share * 100),
        ),
        modifier = Modifier.padding(top = 8.dp),
      )

      // Holds the capsule to the card's floor, so the five buttons line up.
      Spacer(Modifier.weight(1f).heightIn(min = 12.dp))

      // The house capsule minus its bloom: the frosted card is already blooming.
      HeartCapsule(
        title = stringResource(R.string.compassion_donate_hearts),
        onClick = onDonate,
        bloom = false,
        compact = true,
        accessibilityLabel = stringResource(R.string.compassion_donate_hearts_to, cause.name),
      )
    }
  }
}

/**
 * Two figures on one tonal panel, told as labelled rows: a bare "22%" beside
 * a hearts count could be read as a share of anything.
 */
@Composable
private fun TileFacts(
  pooled: String,
  pooledValue: Int,
  share: Float,
  spoken: String,
  modifier: Modifier = Modifier,
) {
  val locale = rememberAppLocale()
  Column(
    modifier
      .fillMaxWidth()
      .pebble(cornerRadius = Dp.tile)
      .padding(horizontal = 10.dp, vertical = 8.dp)
      .clearAndSetSemantics { contentDescription = spoken },
    verticalArrangement = Arrangement.spacedBy(6.dp),
  ) {
    TileFact(CompassionIcons.HeartFill, Color.blushPowder) {
      Text(stringResource(R.string.compassion_hearts_compact, pooled), style = FactMediumStyle, color = Color.deepPlum, maxLines = 1)
    }
    TileFact(CompassionIcons.ChartPieFill, Color.lavenderMist) {
      Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        RollingText(text = AppFormat.percent(share, locale), value = share, style = FactMediumStyle, color = Color.deepPlum)
        Text(stringResource(R.string.compassion_of_giving), style = FactMediumStyle, color = Color.deepPlum, maxLines = 1)
      }
    }
  }
}

@Composable
private fun TileFact(glyph: ImageVector, tint: Color, label: @Composable () -> Unit) {
  Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
    // A fixed glyph column, so the two labels start on the same edge.
    Box(Modifier.width(12.dp), contentAlignment = Alignment.Center) {
      Icon(glyph, contentDescription = null, tint = tint, modifier = Modifier.size(10.dp))
    }
    label()
  }
}

// MARK: - Previews

@Composable
private fun CausesPreview(ledger: HeartLedger) {
  val state by ledger.state.collectAsStateWithLifecycle()
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      CausesSection(
        causes = rememberCompassionContent().causes,
        pool = state.pool,
        onDonate = {},
        modifier = Modifier.padding(vertical = 16.dp),
      )
    }
  }
}

@Preview(showBackground = true, name = "Causes section")
@Composable
private fun CausesSectionPreview() {
  CausesPreview(remember { HeartLedger.sample(Clock.systemDefaultZone(), ZoneId.systemDefault()) })
}

@Preview(showBackground = true, name = "Causes section — large type", fontScale = 1.3f)
@Composable
private fun CausesSectionLargeTypePreview() {
  CausesPreview(remember { HeartLedger.spent(Clock.systemDefaultZone(), ZoneId.systemDefault()) })
}
