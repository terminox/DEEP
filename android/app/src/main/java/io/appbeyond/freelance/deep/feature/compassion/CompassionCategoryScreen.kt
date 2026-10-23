package io.appbeyond.freelance.deep.feature.compassion

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.components.CompassionMotif
import io.appbeyond.freelance.deep.feature.compassion.components.CompassionProjectCard
import io.appbeyond.freelance.deep.feature.compassion.components.HeartBalanceChip
import io.appbeyond.freelance.deep.feature.compassion.components.ImpactPebbles
import io.appbeyond.freelance.deep.feature.compassion.components.ImpactStat
import io.appbeyond.freelance.deep.feature.compassion.components.PartnerOrganizationCard
import io.appbeyond.freelance.deep.feature.compassion.components.SendAHeartBar
import io.appbeyond.freelance.deep.feature.compassion.store.HeartLedger
import io.appbeyond.freelance.deep.feature.profile.HeaderIconButton
import io.appbeyond.freelance.deep.feature.profile.ProfileIcons
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.SectionHeader
import io.appbeyond.freelance.deep.shared.components.ScrollToTopOnReselect
import io.appbeyond.freelance.deep.shared.localization.AppFormat
import io.appbeyond.freelance.deep.shared.localization.rememberAppLocale
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import java.time.Clock
import java.time.ZoneId

/** iOS's `heroHeight: 288`. */
private val HERO_HEIGHT = 288.dp

/** The scrim under the title — iOS's `deepPlum.opacity(0.42)` from the centre down. */
private const val HERO_SCRIM_ALPHA = 0.42f

/** Where the chip leaves the hero for the pale atmosphere — iOS's `heroHeight - 150`, over 60. */
private val BAR_HANDOFF_START = HERO_HEIGHT - 150.dp
private val BAR_HANDOFF_LENGTH = 60.dp

/**
 * A cause in full, told in order: meet it, see its scale, back a project,
 * learn who does the work on the ground, and close on your own part in it.
 * Ending on reflection rather than an ask is deliberate.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/CompassionCategoryView.swift.
 * **Parked, as on iOS:** the route exists (`DeepRoute.CompassionCause`), but
 * nothing pushes it while giving happens on the cause cards — the screen is
 * one call away from returning, not deleted.
 *
 * Its hero is the cause's motif at watermark scale under a plum scrim; iOS's
 * progressive blur is left out (no backdrop blur below API 31), so the scrim
 * alone seats the title.
 *
 * @param give sends hearts to this cause (and a project, when given).
 */
@Composable
fun CompassionCategoryScreen(
  cause: CompassionCause,
  ledger: HeartLedger,
  give: (amount: Int, causeId: String, projectId: String?) -> Unit,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val state by ledger.state.collectAsStateWithLifecycle()
  val locale = rememberAppLocale()
  val scroll = rememberScrollState()
  ScrollToTopOnReselect(scroll)
  val density = LocalDensity.current
  val overHero by remember {
    derivedStateOf {
      val handoff = with(density) { (scroll.value - BAR_HANDOFF_START.toPx()) / BAR_HANDOFF_LENGTH.toPx() }
      handoff < 0.5f
    }
  }

  val stats = listOf(
    ImpactStat(
      label = stringResource(R.string.compassion_hearts_pooled),
      value = AppFormat.compact(state.pool.hearts(cause.id), locale),
      symbol = CompassionIcons.HeartFill,
    ),
    ImpactStat(
      label = stringResource(R.string.compassion_people_reached),
      value = AppFormat.compact(cause.peopleReached, locale),
      symbol = CompassionIcons.PersonTwoFill,
    ),
    ImpactStat(
      label = stringResource(R.string.compassion_share_of_giving),
      value = AppFormat.percent(state.pool.shareOfGiving(cause.id), locale),
      symbol = CompassionIcons.ChartPieFill,
    ),
  )

  Box(modifier.fillMaxSize().background(Color.moonCream)) {
    AtmosphereBackground()

    Column(Modifier.fillMaxSize().verticalScroll(scroll)) {
      Hero(cause)
      Column(
        Modifier
          .fillMaxWidth()
          .padding(top = Dp.rhythm, bottom = Dp.rhythm * 4),
        verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
      ) {
        ImpactPebbles(stats, Modifier.padding(horizontal = Dp.edge))

        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
          SectionHeader(title = stringResource(R.string.compassion_projects_title))
          Column(
            Modifier.padding(horizontal = Dp.edge),
            verticalArrangement = Arrangement.spacedBy(12.dp),
          ) {
            cause.projects.forEach { project ->
              CompassionProjectCard(
                project = project,
                pooled = state.pool.projectHearts(project.id),
                canGive = state.canGive,
                onSend = { give(1, cause.id, project.id) },
              )
            }
          }
        }

        PartnerOrganizationCard(cause.partner, Modifier.padding(horizontal = Dp.edge))

        YourPartCard(cause, state.heartsGiven(cause.id), Modifier.padding(horizontal = Dp.edge))
      }
    }

    Row(
      Modifier
        .fillMaxWidth()
        .statusBarsPadding()
        .padding(horizontal = Dp.edge, vertical = 8.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      HeaderIconButton(
        icon = ProfileIcons.ChevronLeft,
        contentDescription = stringResource(R.string.compassion_back),
        onClick = onBack,
      )
      Box(Modifier.weight(1f))
      HeartBalanceChip(balance = state.balance, overDarkHero = overHero)
    }

    SendAHeartBar(
      causeName = cause.name,
      balance = state.balance,
      failure = state.spendFailure?.takeIf { it.categoryId == cause.id },
      onSend = { give(1, cause.id, null) },
      modifier = Modifier.align(Alignment.BottomCenter).navigationBarsPadding(),
    )
  }
}

/**
 * The cause's motif at hero scale: a large, faint, cropped watermark (a crisp
 * centred glyph this size reads as a missing image), feathered at its foot so
 * it dissolves into the atmosphere instead of ending on a line.
 */
@Composable
private fun Hero(cause: CompassionCause) {
  Box(
    Modifier
      .fillMaxWidth()
      .height(HERO_HEIGHT)
      .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
      .drawWithFeather(),
    contentAlignment = Alignment.BottomStart,
  ) {
    CompassionMotif(
      symbol = cause.symbol,
      palette = cause.palette,
      cornerRadius = 0.dp,
      symbolScale = 0.95f,
      symbolOpacity = 0.22f,
      symbolShadow = false,
      symbolAlignment = Alignment.CenterEnd,
      bordered = false,
      modifier = Modifier.fillMaxSize(),
    )
    Box(
      Modifier
        .fillMaxSize()
        .background(
          Brush.verticalGradient(
            0.5f to Color.Transparent,
            1f to Color.deepPlum.copy(alpha = HERO_SCRIM_ALPHA),
          ),
        ),
    )
    Column(
      Modifier
        .padding(horizontal = Dp.edge)
        .padding(bottom = 48.dp)
        .semantics(mergeDescendants = true) {},
      verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
      Text(cause.name, style = DeepType.wordmark, color = Color.White)
      Text(cause.tagline, style = DeepType.body, color = Color.White.copy(alpha = 0.9f))
    }
  }
}

/** The bottom 15% fades out — iOS's mask stop at 0.85. Needs an offscreen layer. */
private fun Modifier.drawWithFeather(): Modifier = drawWithContent {
  drawContent()
  drawRect(
    brush = Brush.verticalGradient(0.85f to Color.Black, 1f to Color.Transparent),
    blendMode = BlendMode.DstIn,
  )
}

/**
 * What this member has put into the cause, told in a sentence — a stat column
 * would make one warm fact look like a scoreboard. With nothing given yet it
 * becomes an invitation.
 */
@Composable
private fun YourPartCard(cause: CompassionCause, heartsGiven: Int, modifier: Modifier = Modifier) {
  val locale = rememberAppLocale()
  val line = if (heartsGiven > 0) {
    pluralStringResource(R.plurals.compassion_your_part_sent, heartsGiven, AppFormat.number(heartsGiven, locale))
  } else {
    stringResource(R.string.compassion_your_part_none)
  }
  Column(
    modifier
      .fillMaxWidth()
      .frostedCard(tint = cause.palette.colors.first())
      .padding(18.dp)
      .semantics(mergeDescendants = true) {},
    verticalArrangement = Arrangement.spacedBy(8.dp),
  ) {
    Text(stringResource(R.string.compassion_your_part), style = DeepType.micro, color = Color.lavenderMist)
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
      Icon(
        CompassionIcons.HeartFill,
        contentDescription = null,
        tint = Color.blushPowder,
        modifier = Modifier.padding(top = 4.dp).size(15.dp),
      )
      Text(line, style = DeepType.body, color = Color.deepPlum, modifier = Modifier.weight(1f))
    }
  }
}

// MARK: - Previews

@Composable
private fun CategoryPreview(causeId: String, ledger: (Clock, ZoneId) -> HeartLedger) {
  val held = remember { ledger(Clock.systemDefaultZone(), ZoneId.systemDefault()) }
  DeepTheme {
    val cause = rememberCompassionContent().cause(causeId)!!
    CompassionCategoryScreen(cause = cause, ledger = held, give = { _, _, _ -> }, onBack = {})
  }
}

@Preview(showBackground = true, name = "Compassion — cause detail", heightDp = 1400)
@Composable
private fun CompassionCategoryPreview() = CategoryPreview("healthcare", HeartLedger.Companion::sample)

@Preview(showBackground = true, name = "Compassion — cause detail (spent)", heightDp = 1400)
@Composable
private fun CompassionCategorySpentPreview() = CategoryPreview("peace", HeartLedger.Companion::spent)

@Preview(showBackground = true, name = "Compassion — cause detail (nothing given)", heightDp = 1400)
@Composable
private fun CompassionCategoryFreshPreview() = CategoryPreview("community", HeartLedger.Companion::fresh)
