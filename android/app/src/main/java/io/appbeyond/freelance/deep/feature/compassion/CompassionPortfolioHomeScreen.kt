package io.appbeyond.freelance.deep.feature.compassion

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.layout
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.components.CausesSection
import io.appbeyond.freelance.deep.feature.compassion.components.CommunityPoolCard
import io.appbeyond.freelance.deep.feature.compassion.components.CompassionPortfolioCard
import io.appbeyond.freelance.deep.feature.compassion.components.FieldReportsSection
import io.appbeyond.freelance.deep.feature.compassion.store.HeartLedger
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.CollapsibleHomeHeader
import io.appbeyond.freelance.deep.shared.components.HeroRefreshable
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.components.LoopingVideoView
import io.appbeyond.freelance.deep.shared.components.StretchyHero
import io.appbeyond.freelance.deep.shared.components.rememberHeroPull
import io.appbeyond.freelance.deep.shared.components.ScrollToTopOnReselect
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import java.time.Clock
import java.time.ZoneId

// MARK: - Constants

/** iOS's `heroHeight: 320`. */
private val HERO_HEIGHT = 320.dp

/** How far the balance card rides up over the hero — iOS's `heroOverlap: 56`. */
private val HERO_OVERLAP = 56.dp

// MARK: - Screen

/**
 * The Compassion portfolio home — one quiet scroll that reads as a story: an
 * atmospheric hero, then what you hold, then where the community's hearts have
 * gone, then the causes they flow to, and finally the dispatches that show
 * what came back.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/CompassionPortfolioHomeView.swift,
 * in the shape the other hero screens take: [HeroRefreshable] outermost,
 * [CollapsibleHomeHeader] around the list, a [StretchyHero] leading it on the
 * bundled sky loop. No trailing balance chip — the portfolio card carries that
 * number a few points below.
 *
 * A leaf screen: it paints its own [AtmosphereBackground] and hosts no
 * navigation; the donate sheet is the coordinator's to present ([onDonate]).
 *
 * @param onRefresh the pull. One pull refreshes the garden, and the wallet
 *   rides that response into [ledger] — iOS's `gardenStore.refresh()`. Must
 *   swallow its own failures.
 */
@Composable
fun CompassionPortfolioHomeScreen(
  ledger: HeartLedger,
  onDonate: (CompassionCause) -> Unit,
  onRefresh: suspend () -> Unit,
  modifier: Modifier = Modifier,
) {
  val state by ledger.state.collectAsStateWithLifecycle()
  val content = rememberCompassionContent()
  val listState = rememberLazyListState()
  ScrollToTopOnReselect(listState)
  val (pull, nestedScroll) = rememberHeroPull(listState)
  val bottomInset = Dp.rhythm + LocalMiniPlayerClearance.current

  HeroRefreshable(pull = pull, onRefresh = onRefresh, modifier = modifier) {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground()

      CollapsibleHomeHeader(
        title = stringResource(R.string.compassion_title),
        subtitle = stringResource(R.string.compassion_subtitle),
        listState = listState,
        modifier = Modifier.fillMaxSize(),
      ) {
        LazyColumn(
          state = listState,
          modifier = Modifier.fillMaxSize().nestedScroll(nestedScroll),
          contentPadding = PaddingValues(bottom = bottomInset),
        ) {
          item(key = "hero") {
            StretchyHero(pull = pull, listState = listState, height = HERO_HEIGHT) {
              LoopingVideoView(resource = R.raw.sky, modifier = Modifier.fillMaxSize())
            }
          }

          // Mine, then ours: the two cards' blooms overlap at the rhythm, which
          // is what makes them read as one pair rather than two tallies.
          item(key = "portfolio") {
            CompassionPortfolioCard(
              ledger = ledger,
              modifier = Modifier.riseOver(HERO_OVERLAP).padding(horizontal = Dp.edge),
            )
          }

          item(key = "pool") {
            CommunityPoolCard(
              causes = content.causes,
              pool = state.pool,
              peopleReached = content.peopleReached,
              modifier = Modifier.padding(top = Dp.rhythm).padding(horizontal = Dp.edge),
            )
          }

          item(key = "causes") {
            CausesSection(
              causes = content.causes,
              pool = state.pool,
              onDonate = onDonate,
              modifier = Modifier.padding(top = Dp.rhythm),
            )
          }

          // The causes shelf already pays the plume's room beneath its tiles.
          item(key = "reports") {
            FieldReportsSection(reports = content.reports)
          }
        }
      }
    }
  }
}

/**
 * Pulls the element up by [overlap] and gives that height back, the way
 * SwiftUI's negative top padding does — the measure the other hero screens use.
 */
private fun Modifier.riseOver(overlap: Dp): Modifier = layout { measurable, constraints ->
  val placeable = measurable.measure(constraints)
  val rise = overlap.roundToPx()
  layout(placeable.width, (placeable.height - rise).coerceAtLeast(0)) {
    placeable.place(0, -rise)
  }
}

// MARK: - Previews

@Composable
private fun HomePreview(ledger: HeartLedger) {
  DeepTheme {
    CompassionPortfolioHomeScreen(ledger = ledger, onDonate = {}, onRefresh = {})
  }
}

@Preview(showBackground = true, name = "Compassion — home")
@Composable
private fun CompassionHomePreview() {
  HomePreview(remember { HeartLedger.sample(Clock.systemDefaultZone(), ZoneId.systemDefault()) })
}

@Preview(showBackground = true, name = "Compassion — fresh start")
@Composable
private fun CompassionHomeFreshPreview() {
  HomePreview(remember { HeartLedger.fresh(Clock.systemDefaultZone(), ZoneId.systemDefault()) })
}

/** The one state where the balance reads as everything given away. */
@Preview(showBackground = true, name = "Compassion — spent")
@Composable
private fun CompassionHomeSpentPreview() {
  HomePreview(remember { HeartLedger.spent(Clock.systemDefaultZone(), ZoneId.systemDefault()) })
}
