package io.appbeyond.freelance.deep.feature.globalpause

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyItemScope
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.layout
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsound.components.rememberBalancingBreath
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.globalpause.components.DJFukuLoungeCard
import io.appbeyond.freelance.deep.feature.globalpause.components.DeepSessionEntryCard
import io.appbeyond.freelance.deep.feature.globalpause.components.FeatureCarousel
import io.appbeyond.freelance.deep.feature.globalpause.components.HOME_TILE_SIZE
import io.appbeyond.freelance.deep.feature.globalpause.components.HomeSectionHeader
import io.appbeyond.freelance.deep.feature.globalpause.components.RecommendationsSection
import io.appbeyond.freelance.deep.networking.CategoryDto
import io.appbeyond.freelance.deep.networking.PauseHomeDto
import io.appbeyond.freelance.deep.networking.PauseHomeRepository
import io.appbeyond.freelance.deep.networking.PauseHomeResult
import io.appbeyond.freelance.deep.networking.PauseSectionDto
import io.appbeyond.freelance.deep.networking.toDomain
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.CollapsibleHomeHeader
import io.appbeyond.freelance.deep.shared.components.HeroRefreshable
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.components.ScrollToTopOnReselect
import io.appbeyond.freelance.deep.shared.components.LoopingVideoView
import io.appbeyond.freelance.deep.shared.components.SkeletonBlock
import io.appbeyond.freelance.deep.shared.components.SkeletonTextLine
import io.appbeyond.freelance.deep.shared.components.StretchyHero
import io.appbeyond.freelance.deep.shared.components.rememberHeroPull
import io.appbeyond.freelance.deep.shared.components.skeletonBreath
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softPress
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

/** What the home feed is showing. */
sealed interface HomeState {
  data object Loading : HomeState
  data class Loaded(val home: PauseHomeDto) : HomeState
  data object Failed : HomeState
}

/**
 * Home — the root of Global Pause, and deliberately the first thing you see.
 *
 * One slow scroll: a video sky stretching under the status bar, then the content
 * riding up over it. The two fixed cards come first — DJ Fuku's Lounge, the
 * doorway into the world's pause, with its ON AIR badge burning while the
 * nightly set runs, and the [DeepSessionEntryCard] into today's breath — and
 * the server-composed sections follow, in server order: "Made for you"
 * (`forYou`) as a [RecommendationsSection] of square tiles, every other section
 * as a [FeatureCarousel] of landscape cards with a "See all", then the Explore
 * category grid. The pull re-resolves the pause schedule alongside the feed.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Components/GlobalPauseHomeView.swift
 * (705b6b4). The Compose shape of `.collapsibleHomeHeader` and
 * `.heroRefreshable` is two containers, as in `DeepSoundHomeScreen` —
 * [HeroRefreshable] outermost, so its cue draws over the header;
 * [CollapsibleHomeHeader] inside it, wrapping only the list so its blur never
 * reaches [AtmosphereBackground] behind it.
 *
 * **The feed survives a return to Home's root.** This screen is rebuilt each
 * time (iOS's view stays alive under the push instead), so it opens on the
 * feed [PauseHomeRepository.cached] kept and reloads it silently: the skeleton
 * shows only when there is nothing to show, as iOS's `load()` does, and a
 * failed reload over a feed keeps the feed.
 *
 * @param refreshKey an opaque value the load keys on alongside [repository] and
 *   the retry counter — pass the signed-in account id (or `null` when signed
 *   out) so a switched account reloads the feed and picks up its own
 *   personalised shelf, rather than continuing to show the previous member's.
 * @param onOpenCollection asks the coordinator to push a collection's detail —
 *   iOS's `openCollection`, which a tile's or card's body calls.
 * @param onPlayCollection starts a collection playing in place — the small
 *   round play button on a tile or card (iOS's `soundPlayer.play(collection)`).
 * @param onOpenCollectionList asks the coordinator to push a titled list of
 *   collections — a section's "See all" or an Explore category (iOS's
 *   `openCollectionList`).
 */
@Composable
fun GlobalPauseHomeScreen(
  repository: PauseHomeRepository?,
  onOpenDeepSession: (DeepSession) -> Unit,
  modifier: Modifier = Modifier,
  refreshKey: Any? = null,
  onOpenCollection: (SoundCollection) -> Unit = {},
  onPlayCollection: (SoundCollection) -> Unit = {},
  onOpenCollectionList: (title: String, collections: List<SoundCollection>) -> Unit = { _, _ -> },
  isFukuOnAir: Boolean = false,
  onOpenFukuLounge: () -> Unit = {},
  onRefreshPause: suspend () -> Unit = {},
) {
  val state = remember(repository, refreshKey) {
    mutableStateOf<HomeState>(repository?.cached(refreshKey)?.let(HomeState::Loaded) ?: HomeState.Loading)
  }
  var attempt by remember { mutableIntStateOf(0) }

  // Every arrival reloads — silently over a kept feed.
  LaunchedEffect(repository, refreshKey, attempt) { loadHome(repository, refreshKey, state) }

  val listState = rememberLazyListState()
  val (pull, nestedScroll) = rememberHeroPull(listState)
  ScrollToTopOnReselect(listState)
  val session = rememberBalancingBreath()
  // iOS's trailing `.rhythm` of breathing room, after the stack's own spacing.
  val bottomInset = Dp.rhythm * 2 + LocalMiniPlayerClearance.current

  HeroRefreshable(
    pull = pull,
    // Feed content and the pause schedule refresh together; the schedule
    // fetch also re-syncs the clock, so dev time travel lands here too.
    onRefresh = {
      coroutineScope {
        launch { onRefreshPause() }
        loadHome(repository, refreshKey, state)
      }
    },
    modifier = modifier,
  ) {
    Box(
      Modifier
        .fillMaxSize()
        .background(Color.moonCream),
    ) {
      AtmosphereBackground()

      CollapsibleHomeHeader(
        title = stringResource(R.string.home_header_title),
        subtitle = stringResource(R.string.home_header_subtitle),
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
            StretchyHero(pull = pull, listState = listState) {
              LoopingVideoView(resource = R.raw.sky, modifier = Modifier.fillMaxSize())
            }
          }

          // The content rides up over the hero's feathered bottom rather than
          // starting beneath it, which is what makes the two read as one
          // surface. Only this first item rises; everything after follows it.
          item(key = "cards") {
            Column(
              Modifier
                .riseOver(HERO_OVERLAP)
                .padding(horizontal = Dp.edge),
              verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
            ) {
              DJFukuLoungeCard(isOnAir = isFukuOnAir, onOpen = onOpenFukuLounge)
              DeepSessionEntryCard(session = session, onOpen = onOpenDeepSession)
            }
          }

          when (val current = state.value) {
            HomeState.Loading -> item(key = "skeleton") {
              PauseFeedSkeleton(Modifier.feedItem(this))
            }

            HomeState.Failed -> item(key = "failed") {
              HomeFailed(onRetry = { attempt += 1 }, modifier = Modifier.feedItem(this))
            }

            is HomeState.Loaded -> {
              items(current.home.sections, key = { "section-${it.key}" }) { section ->
                Section(
                  section = section,
                  onOpenCollection = onOpenCollection,
                  onPlayCollection = onPlayCollection,
                  onOpenCollectionList = onOpenCollectionList,
                  modifier = Modifier.feedItem(this),
                )
              }

              // Always, as on iOS — the header stands even over no categories.
              item(key = "explore") {
                ExploreSection(
                  categories = current.home.categories,
                  onOpenCollectionList = onOpenCollectionList,
                  modifier = Modifier.feedItem(this),
                )
              }
            }
          }
        }
      }
    }
  }
}

/**
 * iOS's `load()`: the skeleton only returns when there is nothing to keep on
 * screen, and a reload that fails over an already-loaded feed keeps it,
 * silently — a feed that was fine a moment ago is worth more than an error.
 */
private suspend fun loadHome(
  repository: PauseHomeRepository?,
  key: Any?,
  state: MutableState<HomeState>,
) {
  if (repository == null) return
  if (state.value !is HomeState.Loaded) state.value = HomeState.Loading
  state.value = when (val result = repository.load(key)) {
    is PauseHomeResult.Loaded -> HomeState.Loaded(result.home)
    is PauseHomeResult.Failed -> state.value as? HomeState.Loaded ?: HomeState.Failed
  }
}

/** A feed item: `.rhythm` below the one before, blooming in and out — iOS's `.animation(.bloom, value: loadState)`. */
private fun Modifier.feedItem(scope: LazyItemScope): Modifier = with(scope) {
  this@feedItem
    .animateItem(fadeInSpec = bloom(), fadeOutSpec = bloom(), placementSpec = null)
    .padding(top = Dp.rhythm)
}

/**
 * Pulls the element up by [overlap] *and* gives that height back, the way
 * SwiftUI's negative top padding does — so the next item starts right under
 * this one's visible edge, not [overlap] further down as `Modifier.offset`
 * would leave it. `DeepSoundHomeScreen`'s twin.
 */
private fun Modifier.riseOver(overlap: Dp): Modifier = layout { measurable, constraints ->
  val placeable = measurable.measure(constraints)
  val rise = overlap.roundToPx()
  layout(placeable.width, (placeable.height - rise).coerceAtLeast(0)) {
    placeable.place(0, -rise)
  }
}

/** One server section, mapped to the app's collections once per section. */
@Composable
private fun Section(
  section: PauseSectionDto,
  onOpenCollection: (SoundCollection) -> Unit,
  onPlayCollection: (SoundCollection) -> Unit,
  onOpenCollectionList: (title: String, collections: List<SoundCollection>) -> Unit,
  modifier: Modifier = Modifier,
) {
  val collections = remember(section) { section.collections.map { it.toDomain() } }
  if (section.key == FOR_YOU_SECTION) {
    RecommendationsSection(
      title = section.title,
      collections = collections,
      onOpen = onOpenCollection,
      onPlay = onPlayCollection,
      modifier = modifier,
    )
  } else {
    FeatureCarousel(
      title = section.title,
      collections = collections,
      onOpen = onOpenCollection,
      onPlay = onPlayCollection,
      onSeeAll = { onOpenCollectionList(section.title, collections) },
      modifier = modifier,
    )
  }
}

/**
 * The home's "Explore" section — a two-column grid of category tiles, one per
 * backend category: the category's lead-collection artwork under a scrim with
 * the category name laid over it. `LazyColumn` cannot nest another lazy grid
 * inside a single item without a fixed height, so this lays the tiles out with
 * a plain `Column` of `Row`s instead — the category count is small enough that
 * nothing here needs to be lazy.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Components/ExploreByContentSection.swift.
 * Tapping a tile pushes the category's collection list via
 * [onOpenCollectionList], as iOS's `openCollectionList` does.
 */
@Composable
private fun ExploreSection(
  categories: List<CategoryDto>,
  onOpenCollectionList: (title: String, collections: List<SoundCollection>) -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(
    modifier,
    verticalArrangement = Arrangement.spacedBy(EXPLORE_SPACING),
  ) {
    HomeSectionHeader(title = stringResource(R.string.home_explore_title))

    Column(
      Modifier.padding(horizontal = Dp.edge),
      verticalArrangement = Arrangement.spacedBy(EXPLORE_GAP),
    ) {
      categories.chunked(2).forEach { row ->
        Row(horizontalArrangement = Arrangement.spacedBy(EXPLORE_GAP)) {
          row.forEach { category ->
            ExploreTile(category, onOpenCollectionList, Modifier.weight(1f))
          }
          // An odd category out fills its row alone; the empty weight keeps
          // it at half width rather than stretching to fill the row.
          if (row.size == 1) {
            Spacer(Modifier.weight(1f))
          }
        }
      }
    }
  }
}

@Composable
private fun ExploreTile(
  category: CategoryDto,
  onOpen: (title: String, collections: List<SoundCollection>) -> Unit,
  modifier: Modifier = Modifier,
) {
  val artwork = category.collections?.firstOrNull()
  val label = stringResource(R.string.home_explore_category, category.title)
  val open = { onOpen(category.title, (category.collections ?: emptyList()).map { it.toDomain() }) }
  Box(
    modifier
      .height(EXPLORE_TILE_HEIGHT)
      .softPress()
      .clip(RoundedCornerShape(EXPLORE_TILE_RADIUS))
      .clickable(interactionSource = null, indication = null) { open() }
      .clearAndSetSemantics {
        contentDescription = label
        role = Role.Button
        onClick { open(); true }
      },
  ) {
    ArtworkImage(
      url = artwork?.imageUrl,
      palette = artwork?.palette,
      modifier = Modifier.fillMaxSize(),
    )
    // Scrim so the title stays legible over a photograph.
    Box(
      Modifier
        .fillMaxSize()
        .background(
          Brush.verticalGradient(
            colorStops = arrayOf(
              0.5f to Color.Transparent,
              1f to Color.deepPlum.copy(alpha = EXPLORE_SCRIM_ALPHA),
            ),
          ),
        ),
    )
    Text(
      text = category.title,
      style = DeepType.displayTitle,
      color = Color.White,
      modifier = Modifier
        .align(Alignment.BottomStart)
        .padding(EXPLORE_TILE_INSET),
    )
  }
}

/**
 * Loading placeholder for the feed — mirrors a [RecommendationsSection] and a
 * [FeatureCarousel] so the skeleton settles into real content without a
 * layout jump. Ported from PauseFeedSkeleton.swift.
 */
@Composable
private fun PauseFeedSkeleton(modifier: Modifier = Modifier) {
  Column(
    modifier.skeletonBreath(),
    verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
  ) {
    SkeletonShelf(titleWidth = 140.dp) {
      repeat(3) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
          SkeletonBlock(Modifier.size(HOME_TILE_SIZE))
          Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            SkeletonTextLine(width = 110.dp)
            SkeletonTextLine(width = 70.dp)
          }
        }
      }
    }
    SkeletonShelf(titleWidth = 160.dp) {
      repeat(2) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
          SkeletonBlock(Modifier.size(width = 300.dp, height = 200.dp), cornerRadius = Dp.card)
          Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
            SkeletonTextLine(width = 160.dp)
            SkeletonTextLine(width = 110.dp)
          }
        }
      }
    }
  }
}

/** A title line over a row that runs off the trailing edge, as the shelves do. */
@Composable
private fun SkeletonShelf(titleWidth: Dp, row: @Composable () -> Unit) {
  Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
    SkeletonTextLine(Modifier.padding(horizontal = Dp.edge), width = titleWidth)
    LazyRow(
      contentPadding = PaddingValues(horizontal = Dp.edge),
      horizontalArrangement = Arrangement.spacedBy(16.dp),
      userScrollEnabled = false,
    ) {
      item { Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) { row() } }
    }
  }
}

/**
 * The failed state — iOS's one quiet line and a frosted "Try again" chip.
 *
 * It deliberately does **not** fall back to bundled sample content: onboarding
 * learned that the hard way, where fixture trees shared ids and names with the
 * real rows and a dead backend rendered as a working picker.
 */
@Composable
private fun HomeFailed(
  onRetry: () -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(
    modifier
      .fillMaxWidth()
      .padding(horizontal = Dp.edge, vertical = FAILED_PADDING_VERTICAL),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(FAILED_SPACING),
  ) {
    Text(
      stringResource(R.string.home_failed),
      style = DeepType.body,
      color = Color.driftGrey,
      textAlign = TextAlign.Center,
    )
    Text(
      stringResource(R.string.home_retry),
      style = DeepType.bodyMedium,
      color = Color.deepPlum,
      modifier = Modifier
        .softPress()
        .frostedCard(cornerRadius = Dp.chip)
        .clickable(interactionSource = null, indication = null, role = Role.Button, onClick = onRetry)
        .padding(horizontal = RETRY_PADDING_HORIZONTAL, vertical = RETRY_PADDING_VERTICAL),
    )
  }
}

/** The personalised section's server key — rendered as square tiles, not cards. */
private const val FOR_YOU_SECTION = "forYou"

private val HERO_OVERLAP = 80.dp

/** Explore — `VStack(spacing: 14)`, a 12pt grid, 92pt tiles at radius 18 with a 14pt inset. */
private val EXPLORE_SPACING = 14.dp
private val EXPLORE_GAP = 12.dp
private val EXPLORE_TILE_HEIGHT = 92.dp
private val EXPLORE_TILE_RADIUS = 18.dp
private val EXPLORE_TILE_INSET = 14.dp
private const val EXPLORE_SCRIM_ALPHA = 0.5f

/** The failed note — `VStack(spacing: 14)`, `.padding(.vertical, 48)`; the chip's 22 × 12. */
private val FAILED_SPACING = 14.dp
private val FAILED_PADDING_VERTICAL = 48.dp
private val RETRY_PADDING_HORIZONTAL = 22.dp
private val RETRY_PADDING_VERTICAL = 12.dp

@Preview(showBackground = true, name = "Loading")
@Composable
private fun GlobalPauseHomeLoadingPreview() {
  DeepTheme { GlobalPauseHomeScreen(repository = null, onOpenDeepSession = {}) }
}

@Preview(showBackground = true, name = "Explore section")
@Composable
private fun ExploreSectionPreview() {
  DeepTheme {
    Column(Modifier.fillMaxWidth().background(Color.moonCream)) {
      ExploreSection(
        categories = listOf(
          CategoryDto(id = "calm", slug = "calm", title = "Calm"),
          CategoryDto(id = "morning", slug = "morning", title = "Morning"),
          CategoryDto(id = "sleep", slug = "sleep", title = "Sleep"),
        ),
        onOpenCollectionList = { _, _ -> },
      )
    }
  }
}

@Preview(showBackground = true, name = "Feed skeleton")
@Composable
private fun PauseFeedSkeletonPreview() {
  DeepTheme {
    Column(Modifier.fillMaxWidth().background(Color.moonCream)) {
      PauseFeedSkeleton()
    }
  }
}

@Preview(showBackground = true, name = "Failed")
@Composable
private fun HomeFailedPreview() {
  DeepTheme {
    Box(Modifier.background(Color.moonCream)) {
      HomeFailed(onRetry = {})
    }
  }
}
