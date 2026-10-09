package io.appbeyond.freelance.deep.feature.mindgarden.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathData
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenGreeting
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenGrowth
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.PlantGrowthHalo
import io.appbeyond.freelance.deep.shared.components.SkeletonBlock
import io.appbeyond.freelance.deep.shared.components.SkeletonTextLine
import io.appbeyond.freelance.deep.shared.components.SunlightFact
import io.appbeyond.freelance.deep.shared.components.skeletonBreath
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

/** The card's inset — the house card grammar's 20. */
private val CARD_PADDING = 20.dp

/** Salutation block to growth row — iOS's `VStack(spacing: 16)`. */
private val CARD_SPACING = 16.dp

/** Salutation to quote — iOS's `VStack(spacing: 3)`. */
private val SALUTATION_SPACING = 3.dp

/** Halo column to copy column. */
private val ROW_SPACING = 16.dp

/** Halo to the change pill hanging beneath it. */
private val PILL_GAP = 10.dp

/** Stage name to sunlight fact — iOS's `VStack(spacing: 5)`. */
private val COPY_SPACING = 5.dp

/**
 * The halo's whole footprint: an 84 portrait plus 5 of gap and 3.5 of ring on
 * each side — what the copy column centres against.
 */
private val HALO_DIAMETER = 101.dp

/** The pill's glyph — iOS's 10pt semibold symbol, measured to its box. */
private val PILL_GLYPH_SIZE = 11.dp
private val PILL_GLYPH_SPACING = 5.dp
private val PILL_PADDING_HORIZONTAL = 12.dp
private val PILL_PADDING_VERTICAL = 7.dp

/** The card's inset tonal panel — iOS's `pebble`, white at 0.38. */
private const val PEBBLE_ALPHA = 0.38f

private val PILL_LABEL_STYLE = DeepType.caption.copy(fontWeight = FontWeight.Medium)

// MARK: - Card

/**
 * The garden's opening card — a greeting over the plant itself: only the
 * current form, held in a halo that closes as sunlight banks. The next form is
 * named, never shown — evolving stays something to look forward to — and
 * beside the name sits the one fact that matters: how much sunlight still
 * stands between this plant and what it becomes next.
 *
 * Ported from Deep/Deep/Features/MindGarden/Components/GardenGrowthCard.swift.
 * The greeting takes the whole card width — nothing shares its line, so the
 * day's quote breaks where the sentence wants to rather than where a chip in
 * the corner forces it.
 *
 * @param onChangePlant when set, a quiet "Change" pill hangs under the plant's
 *   portrait — the way into the plant picker. Null (previews, fixtures) hides it.
 */
@Composable
fun GardenGrowthCard(
  greeting: GardenGreeting,
  growth: GardenGrowth,
  modifier: Modifier = Modifier,
  onChangePlant: (() -> Unit)? = null,
) {
  Column(
    modifier
      .fillMaxWidth()
      .frostedCard()
      .padding(CARD_PADDING),
    verticalArrangement = Arrangement.spacedBy(CARD_SPACING),
  ) {
    Column(
      Modifier.fillMaxWidth(),
      verticalArrangement = Arrangement.spacedBy(SALUTATION_SPACING),
    ) {
      val salutation = when (greeting.timeOfDay) {
        GardenGreeting.TimeOfDay.Morning -> R.string.garden_salutation_morning
        GardenGreeting.TimeOfDay.Afternoon -> R.string.garden_salutation_afternoon
        GardenGreeting.TimeOfDay.Evening -> R.string.garden_salutation_evening
      }
      val quotes = stringArrayResource(R.array.garden_quotes)
      Text(stringResource(salutation), style = DeepType.sectionTitle, color = Color.deepPlum)
      Text(quotes[greeting.quoteIndex % quotes.size], style = DeepType.caption, color = Color.driftGrey)
    }

    PlantGrowthRow(growth = growth, onChangePlant = onChangePlant)
  }
}

/**
 * The plant as it stands today: its portrait inside the growth halo, with the
 * way to swap plants hanging beneath it, beside its name and the sunlight it
 * still owes its next form.
 *
 * iOS seats the copy against the *portrait's* centre with a custom alignment
 * guide, so the pill can hang below the halo without pulling the name down
 * with it. Compose has no alignment guides across a Row's children, so the copy
 * column is given the halo's height and centred inside it — the same seat, and
 * a large font simply grows it downward.
 *
 * One element to TalkBack — the summary tells the whole story in a sentence.
 * Hit testing is untouched, so the pill still taps; TalkBack reaches it through
 * the named custom action instead.
 */
@Composable
private fun PlantGrowthRow(
  growth: GardenGrowth,
  onChangePlant: (() -> Unit)?,
  modifier: Modifier = Modifier,
) {
  val stage = growth.stage
  val next = growth.nextStage
  val goal = growth.sunlightToEvolve
  val summary = if (next != null && goal != null) {
    stringResource(R.string.garden_growth_summary, stage.name, growth.sunlight, goal, next.name)
  } else {
    stringResource(R.string.garden_growth_summary_fully_grown, stage.name)
  }
  val changeAction = stringResource(R.string.garden_change_action)

  Row(
    modifier
      .fillMaxWidth()
      .clearAndSetSemantics {
        contentDescription = summary
        if (onChangePlant != null) {
          customActions = listOf(CustomAccessibilityAction(changeAction) { onChangePlant(); true })
        }
      },
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
  ) {
    Column(
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(PILL_GAP),
    ) {
      PlantGrowthHalo(
        progress = growth.evolutionProgress.toFloat(),
        portraitUrl = stage.mascotUrl ?: stage.mascotBgUrl,
        palette = growth.plant.palette,
      )
      if (onChangePlant != null) ChangePill(onClick = onChangePlant)
    }

    Box(
      Modifier
        .weight(1f)
        .heightIn(min = HALO_DIAMETER),
      contentAlignment = Alignment.CenterStart,
    ) {
      Column(verticalArrangement = Arrangement.spacedBy(COPY_SPACING)) {
        Text(stage.name, style = DeepType.displayTitle, color = Color.deepPlum)
        SunlightFact(sunlight = growth.sunlight, goal = goal, nextStageName = next?.name)
      }
    }
  }
}

/**
 * The way into the plant picker, centred under the plant it would swap: the
 * card's own inset tonal panel drawn as a pill, so it reads as a real
 * affordance without borrowing a CTA's weight.
 */
@Composable
private fun ChangePill(onClick: () -> Unit, modifier: Modifier = Modifier) {
  Row(
    modifier
      .softPress()
      .background(Color.White.copy(alpha = PEBBLE_ALPHA), RoundedCornerShape(Dp.chip))
      .clickable(
        interactionSource = null,
        indication = null,
        role = Role.Button,
        onClick = onClick,
      )
      .padding(horizontal = PILL_PADDING_HORIZONTAL, vertical = PILL_PADDING_VERTICAL),
    horizontalArrangement = Arrangement.spacedBy(PILL_GLYPH_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(
      imageVector = SwapGlyph,
      contentDescription = null,
      tint = Color.deepPlum,
      modifier = Modifier.size(PILL_GLYPH_SIZE),
    )
    Text(
      stringResource(R.string.garden_change),
      style = PILL_LABEL_STYLE,
      color = Color.deepPlum,
      maxLines = 1,
    )
  }
}

/**
 * iOS's `arrow.triangle.2.circlepath`: two arcs chasing each other round a
 * circle, each ending in a chevron. Drawn at a semibold 2.25 stroke rather than
 * the icon set's 1.5, because it is read at caption size, where 1.5 vanishes.
 */
private val SwapGlyph: ImageVector = ImageVector.Builder(
  name = "GardenSwap",
  defaultWidth = 24.dp,
  defaultHeight = 24.dp,
  viewportWidth = 24f,
  viewportHeight = 24f,
).addPath(
  pathData = PathData {
    // Upper arc, r = 7 from 190° to 350° over the top, chevron pointing down.
    moveTo(5.11f, 10.78f)
    arcTo(7f, 7f, 0f, isMoreThanHalf = false, isPositiveArc = true, x1 = 18.89f, y1 = 10.78f)
    moveTo(16.6f, 8.85f)
    lineTo(18.89f, 10.78f)
    lineTo(20.4f, 8.2f)
    // Lower arc, the same turned half a circle, chevron pointing up.
    moveTo(18.89f, 13.22f)
    arcTo(7f, 7f, 0f, isMoreThanHalf = false, isPositiveArc = true, x1 = 5.11f, y1 = 13.22f)
    moveTo(7.4f, 15.15f)
    lineTo(5.11f, 13.22f)
    lineTo(3.6f, 15.8f)
  },
  fill = null,
  stroke = SolidColor(Color.Black), // replaced by the Icon tint at the call site
  strokeLineWidth = 2.25f,
  strokeLineCap = StrokeCap.Round,
  strokeLineJoin = StrokeJoin.Round,
).build()

// MARK: - Skeleton

/**
 * Mirrors the growth card's geometry — salutation lines, the halo's circle
 * with the change pill beneath it, the name and fact lines — while the first
 * garden snapshot is still on its way, so the page doesn't reflow when the
 * plant arrives.
 *
 * Ported from `growthSkeleton` in
 * Deep/Deep/Features/MindGarden/Components/MindGardenHomeView.swift.
 */
@Composable
fun GardenGrowthCardSkeleton(modifier: Modifier = Modifier) {
  Column(
    modifier
      .fillMaxWidth()
      .skeletonBreath()
      .frostedCard()
      .padding(CARD_PADDING),
    verticalArrangement = Arrangement.spacedBy(CARD_SPACING),
  ) {
    Column(verticalArrangement = Arrangement.spacedBy(SKELETON_LINE_SPACING)) {
      SkeletonTextLine(width = 150.dp)
      SkeletonTextLine(width = 230.dp)
    }

    Row(
      horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(PILL_GAP),
      ) {
        SkeletonBlock(Modifier.size(HALO_DIAMETER), cornerRadius = HALO_DIAMETER / 2)
        SkeletonBlock(Modifier.size(width = 92.dp, height = 30.dp), cornerRadius = Dp.chip)
      }

      Column(
        Modifier.weight(1f),
        verticalArrangement = Arrangement.spacedBy(SKELETON_LINE_SPACING),
      ) {
        SkeletonTextLine(width = 130.dp)
        SkeletonTextLine(width = 160.dp)
      }
    }
  }
}

private val SKELETON_LINE_SPACING = 8.dp

// MARK: - Previews

@Composable
private fun CardPreviewBackdrop(content: @Composable () -> Unit) {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      Box(Modifier.padding(Dp.edge)) { content() }
    }
  }
}

@Preview(showBackground = true, name = "Growth — sample")
@Composable
private fun GardenGrowthCardPreview() {
  CardPreviewBackdrop { GardenGrowthCard(greeting = GardenGreeting.sample, growth = GardenGrowth.sample) }
}

@Preview(showBackground = true, name = "Growth — change affordance")
@Composable
private fun GardenGrowthCardChangePreview() {
  CardPreviewBackdrop {
    GardenGrowthCard(greeting = GardenGreeting.sample, growth = GardenGrowth.sample, onChangePlant = {})
  }
}

@Preview(showBackground = true, name = "Growth — fresh")
@Composable
private fun GardenGrowthCardFreshPreview() {
  CardPreviewBackdrop {
    GardenGrowthCard(greeting = GardenGreeting.sample, growth = GardenGrowth.sprouting, onChangePlant = {})
  }
}

@Preview(showBackground = true, name = "Growth — fully grown")
@Composable
private fun GardenGrowthCardFullyGrownPreview() {
  CardPreviewBackdrop {
    GardenGrowthCard(greeting = GardenGreeting.evening, growth = GardenGrowth.fullyGrown, onChangePlant = {})
  }
}

@Preview(showBackground = true, name = "Growth — large type", fontScale = 1.6f)
@Composable
private fun GardenGrowthCardLargeTypePreview() {
  CardPreviewBackdrop {
    GardenGrowthCard(greeting = GardenGreeting.sample, growth = GardenGrowth.sample, onChangePlant = {})
  }
}

@Preview(showBackground = true, name = "Growth — skeleton")
@Composable
private fun GardenGrowthCardSkeletonPreview() {
  CardPreviewBackdrop { GardenGrowthCardSkeleton() }
}
