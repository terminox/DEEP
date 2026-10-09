package io.appbeyond.freelance.deep.feature.mindgarden

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.mindgarden.components.DailyPracticeCard
import io.appbeyond.freelance.deep.feature.mindgarden.components.GardenGrowthCard
import io.appbeyond.freelance.deep.feature.mindgarden.components.GardenGrowthCardSkeleton
import io.appbeyond.freelance.deep.feature.mindgarden.components.PlantPickerSheet
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenGreeting
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenHeroMedia
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant
import io.appbeyond.freelance.deep.feature.mindgarden.store.GardenStore
import io.appbeyond.freelance.deep.feature.practice.store.MockPracticeRemote
import io.appbeyond.freelance.deep.feature.practice.store.PracticeJournal
import io.appbeyond.freelance.deep.feature.rewards.store.MockRewardsRemote
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.CollapsibleHomeHeader
import io.appbeyond.freelance.deep.shared.components.HeroRefreshable
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.components.LoopingVideoView
import io.appbeyond.freelance.deep.shared.components.StretchyHero
import io.appbeyond.freelance.deep.shared.components.rememberHeroPull
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import kotlinx.coroutines.runBlocking
import java.time.Clock
import java.time.ZoneId

// MARK: - Constants

/**
 * The oak owns half the screen on this screen only, so the garden opens on the
 * tree. A fraction of the whole window — the hero bleeds under the status bar,
 * so the safe areas count — rather than a fixed height: half of a small phone
 * is not half of a large one.
 */
private const val HERO_SCREEN_FRACTION = 0.5f

/** How far the growth card rides up over the hero — iOS's `heroOverlap: 52`. */
private val HERO_OVERLAP = 52.dp

// MARK: - Screen

/**
 * The Mind Garden home — a personal calm space. One quiet scroll: an
 * atmospheric video header, a greeting with the plant's growth toward its next
 * form, and a nudge into today's practice carrying today's progress.
 *
 * Ported from Deep/Deep/Features/MindGarden/Components/MindGardenHomeView.swift,
 * in the shape `DeepSoundHomeScreen` gives the hero screens: [HeroRefreshable]
 * outermost so its cue draws over the header, [CollapsibleHomeHeader] inside
 * wrapping only the list, and a [StretchyHero] leading it.
 *
 * The hero plays what [GardenHeroMedia.forGrowth] picks — the bundled
 * mature-oak loop for the oak (and while the garden loads), otherwise the
 * current stage's own footage over its portrait.
 *
 * A leaf screen: it paints its own [AtmosphereBackground] and hosts no
 * navigation. Today's practice is the coordinator's to open ([onOpenSession]).
 * The plant picker is raised here, as a sheet beside the garden rather than a
 * place to travel to — on iOS the coordinator presents it; here the sheet has
 * no route to own, so the screen keeps the one flag.
 *
 * @param garden the plant, its banked sunlight and the picker catalog.
 * @param journal today's practice minutes, read live: a session finished
 *   anywhere regrows the practice card.
 * @param onOpenSession the practice card was tapped — iOS pushes the
 *   balancing-breath DEEP Session threshold.
 * @param onRefresh the pull: refresh the garden and the journal together (iOS
 *   runs `gardenStore.refresh()` and `practice.refresh()` side by side). It
 *   must swallow its own failures.
 * @param greeting the salutation and the day's line. Re-read on every
 *   recomposition, as iOS's body does, so an evening return says good evening.
 */
@Composable
fun MindGardenHomeScreen(
  garden: GardenStore,
  journal: PracticeJournal,
  onOpenSession: () -> Unit,
  onRefresh: suspend () -> Unit,
  modifier: Modifier = Modifier,
  greeting: GardenGreeting = GardenGreeting.current(Clock.systemDefaultZone(), ZoneId.systemDefault()),
) {
  val gardenState by garden.state.collectAsStateWithLifecycle()
  val journalState by journal.state.collectAsStateWithLifecycle()
  // Derived from the journal as it stands, so reading its state keeps the card live.
  val practice = remember(journalState) { journal.gardenState() }
  val growth = gardenState.growth

  var pickingPlant by rememberSaveable { mutableStateOf(false) }

  val listState = rememberLazyListState()
  val (pull, nestedScroll) = rememberHeroPull(listState)
  val bottomInset = Dp.rhythm + LocalMiniPlayerClearance.current
  val windowHeight = LocalWindowInfo.current.containerSize.height
  val heroHeight = with(LocalDensity.current) { (windowHeight * HERO_SCREEN_FRACTION).toDp() }

  HeroRefreshable(
    pull = pull,
    onRefresh = onRefresh,
    modifier = modifier,
  ) {
    Box(
      Modifier
        .fillMaxSize()
        .background(Color.moonCream),
    ) {
      AtmosphereBackground()

      CollapsibleHomeHeader(
        title = stringResource(R.string.mind_garden_title),
        subtitle = stringResource(R.string.mind_garden_subtitle),
        listState = listState,
        modifier = Modifier.fillMaxSize(),
      ) {
        LazyColumn(
          state = listState,
          modifier = Modifier
            .fillMaxSize()
            .nestedScroll(nestedScroll),
          contentPadding = PaddingValues(bottom = bottomInset),
        ) {
          item(key = "hero") {
            StretchyHero(pull = pull, listState = listState, height = heroHeight) {
              GardenHero(media = GardenHeroMedia.forGrowth(growth))
            }
          }

          // The growth card rides up over the hero's feathered foot, which is
          // what makes the two read as one surface; everything after follows.
          if (growth != null) {
            item(key = "growth") {
              GardenGrowthCard(
                greeting = greeting,
                growth = growth,
                onChangePlant = { pickingPlant = true },
                modifier = Modifier
                  .animateItem(fadeInSpec = bloom(), fadeOutSpec = bloom(), placementSpec = null)
                  .riseOver(HERO_OVERLAP)
                  .padding(horizontal = Dp.edge),
              )
            }
          } else {
            item(key = "growth-skeleton") {
              GardenGrowthCardSkeleton(
                Modifier
                  .animateItem(fadeInSpec = bloom(), fadeOutSpec = bloom(), placementSpec = null)
                  .riseOver(HERO_OVERLAP)
                  .padding(horizontal = Dp.edge),
              )
            }
          }

          item(key = "practice") {
            DailyPracticeCard(
              state = practice,
              plantName = growth?.plant?.name,
              onClick = onOpenSession,
              modifier = Modifier
                .padding(top = Dp.rhythm)
                .padding(horizontal = Dp.edge),
            )
          }
        }
      }
    }
  }

  if (pickingPlant) {
    PlantPickerSheet(garden = garden, onDismiss = { pickingPlant = false })
  }
}

/** The hero's footage: the bundled oak loop, or the stage's own over its portrait. */
@Composable
private fun GardenHero(media: GardenHeroMedia) {
  when (media) {
    GardenHeroMedia.BundledOak ->
      LoopingVideoView(resource = R.raw.deep_oak_mature, modifier = Modifier.fillMaxSize())
    is GardenHeroMedia.RemoteVideo ->
      LoopingVideoView(url = media.url, posterUrl = media.posterUrl, modifier = Modifier.fillMaxSize())
  }
}

/**
 * Pulls the element up by [overlap] *and* gives that height back, the way
 * SwiftUI's negative top padding does — so the next item starts right under
 * this one's visible edge, not [overlap] further down as `Modifier.offset`
 * would leave it. The same measure `DeepSoundHomeScreen` uses.
 */
private fun Modifier.riseOver(overlap: Dp): Modifier = layout { measurable, constraints ->
  val placeable = measurable.measure(constraints)
  val rise = overlap.roundToPx()
  layout(placeable.width, (placeable.height - rise).coerceAtLeast(0)) {
    placeable.place(0, -rise)
  }
}

// MARK: - Previews

/** A mock garden seeded to [sunlight] on the oak, or still loading when [plant] is null. */
private fun previewGarden(plant: Plant?, sunlight: Int): GardenStore =
  GardenStore(remote = MockRewardsRemote(), blob = InMemoryBlobStore()).apply { seed(plant, sunlight) }

/** An in-memory journal holding [minutes] of practice today. */
private fun previewJournal(minutes: Int): PracticeJournal =
  PracticeJournal(
    remote = MockPracticeRemote(),
    blob = InMemoryBlobStore(),
    clock = Clock.systemDefaultZone(),
    zone = ZoneId.systemDefault(),
  ).apply {
    if (minutes > 0) runBlocking { record(title = "Balancing breath", durationSeconds = minutes * 60) }
  }

@Composable
private fun MindGardenPreview(plant: Plant?, sunlight: Int, minutes: Int, greeting: GardenGreeting) {
  val garden = remember { previewGarden(plant, sunlight) }
  val journal = remember { previewJournal(minutes) }
  DeepTheme {
    MindGardenHomeScreen(
      garden = garden,
      journal = journal,
      onOpenSession = {},
      onRefresh = {},
      greeting = greeting,
    )
  }
}

@Preview(showBackground = true, name = "Mind Garden — Home")
@Composable
private fun MindGardenHomePreview() {
  MindGardenPreview(Plant.oakFixture, sunlight = 240, minutes = 7, greeting = GardenGreeting.sample)
}

@Preview(showBackground = true, name = "Mind Garden — Fresh start")
@Composable
private fun MindGardenFreshPreview() {
  MindGardenPreview(Plant.sakuraFixture, sunlight = 0, minutes = 0, greeting = GardenGreeting.sample)
}

@Preview(showBackground = true, name = "Mind Garden — Flourishing")
@Composable
private fun MindGardenFlourishingPreview() {
  MindGardenPreview(Plant.oakFixture, sunlight = 700, minutes = 10, greeting = GardenGreeting.evening)
}

@Preview(showBackground = true, name = "Mind Garden — Loading")
@Composable
private fun MindGardenLoadingPreview() {
  MindGardenPreview(plant = null, sunlight = 0, minutes = 0, greeting = GardenGreeting.sample)
}
