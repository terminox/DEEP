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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.networking.CategoryDto
import io.appbeyond.freelance.deep.networking.CollectionDto
import io.appbeyond.freelance.deep.networking.PauseHomeDto
import io.appbeyond.freelance.deep.networking.PauseHomeRepository
import io.appbeyond.freelance.deep.networking.PauseHomeResult
import io.appbeyond.freelance.deep.networking.PauseSectionDto
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.LoopingVideoView
import io.appbeyond.freelance.deep.shared.components.SkeletonBlock
import io.appbeyond.freelance.deep.shared.components.StretchyHero
import io.appbeyond.freelance.deep.shared.components.rememberHeroPull
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softPress
import io.appbeyond.freelance.deep.theme.tile

/** What one load of the home feed produced. */
sealed interface HomeState {
  data object Loading : HomeState
  data class Loaded(val home: PauseHomeDto) : HomeState
  data class Failed(val message: String) : HomeState
}

/**
 * Home — the root of Global Pause, and deliberately the first thing you see.
 *
 * One slow scroll: a video sky stretching under the status bar, then the content
 * riding up over it. The two fixed cards come first — the doorway into the
 * world's pause, and the doorway into today's breath — and the server-composed
 * shelves follow.
 *
 * `v0.0.1` carried the hero, both cards and the first shelf. `v0.0.2` renders
 * every section the server sends, in server order — including the
 * personalised "Made for you" shelf, which is a `PauseSectionDto` like any
 * other — plus the Explore category grid below them.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Components/GlobalPauseHomeView.swift.
 *
 * @param refreshKey an opaque value the load keys on alongside [repository] and
 *   the retry counter — pass the signed-in account id (or `null` when signed
 *   out) so a switched account reloads the feed and picks up its own
 *   personalised shelf, rather than continuing to show the previous member's.
 */
@Composable
fun GlobalPauseHomeScreen(
  repository: PauseHomeRepository?,
  onOpenDeepSession: (DeepSession) -> Unit,
  modifier: Modifier = Modifier,
  refreshKey: Any? = null,
) {
  var state by remember { mutableStateOf<HomeState>(HomeState.Loading) }
  var attempt by remember { mutableStateOf(0) }

  LaunchedEffect(repository, refreshKey, attempt) {
    if (repository == null) return@LaunchedEffect
    state = HomeState.Loading
    state = when (val result = repository.load()) {
      is PauseHomeResult.Loaded -> HomeState.Loaded(result.home)
      is PauseHomeResult.Failed -> HomeState.Failed(result.error.message)
    }
  }

  val listState = rememberLazyListState()
  val (pull, nestedScroll) = rememberHeroPull(listState)

  Box(
    modifier
      .fillMaxSize()
      .background(Color.moonCream),
  ) {
    AtmosphereBackground()

    LazyColumn(
      state = listState,
      modifier = Modifier
        .fillMaxSize()
        .nestedScroll(nestedScroll),
      contentPadding = PaddingValues(bottom = Dp.rhythm * 2),
    ) {
      item(key = "hero") {
        StretchyHero(pull = pull, listState = listState) {
          LoopingVideoView(resource = R.raw.sky, modifier = Modifier.fillMaxSize())
        }
      }

      // The content rides up over the hero's feathered bottom rather than
      // starting beneath it, which is what makes the two read as one surface.
      item(key = "cards") {
        Column(
          Modifier
            .offset(y = -HERO_OVERLAP)
            .padding(horizontal = Dp.edge),
          verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
          LoungeCard()
          DeepSessionEntryCard(onOpen = onOpenDeepSession)
        }
      }

      when (val current = state) {
        HomeState.Loading -> item(key = "skeleton") {
          HomeSkeleton(Modifier.offset(y = -HERO_OVERLAP))
        }

        is HomeState.Failed -> item(key = "failed") {
          HomeFailed(
            message = current.message,
            onRetry = { attempt += 1 },
            modifier = Modifier.offset(y = -HERO_OVERLAP),
          )
        }

        is HomeState.Loaded -> {
          // Every server-composed shelf, in server order — "Made for you" is
          // just another PauseSectionDto (its `personalized` flag is what the
          // server used to decide whether to include it at all).
          items(current.home.sections, key = { it.key }) { section ->
            Shelf(section, Modifier.offset(y = -HERO_OVERLAP))
          }

          if (current.home.categories.isNotEmpty()) {
            item(key = "explore") {
              ExploreSection(current.home.categories, Modifier.offset(y = -HERO_OVERLAP))
            }
          }
        }
      }
    }
  }
}

@Composable
private fun LoungeCard(modifier: Modifier = Modifier) {
  Column(
    modifier
      .fillMaxWidth()
      .frostedCard()
      .padding(20.dp),
    verticalArrangement = Arrangement.spacedBy(6.dp),
  ) {
    Text(
      stringResource(R.string.home_lounge_card_title),
      style = DeepType.displayTitle,
      color = Color.deepPlum,
    )
    Text(
      stringResource(R.string.home_lounge_card_body),
      style = DeepType.body,
      color = Color.driftGrey,
    )
  }
}

@Composable
private fun DeepSessionEntryCard(
  onOpen: (DeepSession) -> Unit,
  modifier: Modifier = Modifier,
) {
  val title = stringResource(R.string.home_session_card_title)
  val body = stringResource(R.string.home_session_card_body)

  Column(
    modifier
      .fillMaxWidth()
      .frostedCard()
      .softPress()
      .clickable {
        onOpen(DeepSession(id = "balancing-breath", title = title, tagline = body, cycles = 6))
      }
      .padding(20.dp),
    verticalArrangement = Arrangement.spacedBy(6.dp),
  ) {
    Text(title, style = DeepType.displayTitle, color = Color.deepPlum)
    Text(body, style = DeepType.body, color = Color.driftGrey)
  }
}

@Composable
private fun Shelf(section: PauseSectionDto, modifier: Modifier = Modifier) {
  Column(
    modifier.padding(top = Dp.rhythm),
    verticalArrangement = Arrangement.spacedBy(12.dp),
  ) {
    Text(
      text = section.title,
      style = DeepType.sectionTitle,
      color = Color.deepPlum,
      modifier = Modifier.padding(horizontal = Dp.edge),
    )

    LazyRow(
      horizontalArrangement = Arrangement.spacedBy(12.dp),
      contentPadding = PaddingValues(horizontal = Dp.edge),
    ) {
      items(section.collections, key = { it.id }) { collection ->
        CollectionTile(collection)
      }
    }
  }
}

@Composable
private fun CollectionTile(collection: CollectionDto, modifier: Modifier = Modifier) {
  Column(
    modifier.width(TILE_WIDTH),
    verticalArrangement = Arrangement.spacedBy(8.dp),
  ) {
    ArtworkImage(
      url = collection.imageUrl,
      palette = collection.palette,
      contentDescription = collection.title,
      modifier = Modifier
        .size(TILE_WIDTH)
        .clip(RoundedCornerShape(Dp.tile)),
    )
    Text(
      text = collection.title,
      style = DeepType.bodyMedium,
      color = Color.deepPlum,
      maxLines = 2,
      overflow = TextOverflow.Ellipsis,
      // A flexible column rather than a Spacer beside it: a Spacer bids against
      // the text for width and makes titles wrap on rows with room to spare.
      modifier = Modifier.fillMaxWidth(),
    )
    collection.subtitle?.let {
      Text(
        text = it,
        style = DeepType.caption,
        color = Color.driftGrey,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.fillMaxWidth(),
      )
    }
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
 * Tapping a tile does nothing yet — collection-list detail is week 3, matching
 * how [CollectionTile] above has no tap handler either.
 */
@Composable
private fun ExploreSection(categories: List<CategoryDto>, modifier: Modifier = Modifier) {
  Column(
    modifier.padding(top = Dp.rhythm),
    verticalArrangement = Arrangement.spacedBy(14.dp),
  ) {
    Text(
      text = stringResource(R.string.home_explore_title),
      style = DeepType.sectionTitle,
      color = Color.deepPlum,
      modifier = Modifier.padding(horizontal = Dp.edge),
    )

    Column(
      Modifier.padding(horizontal = Dp.edge),
      verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
      categories.chunked(2).forEach { row ->
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
          row.forEach { category ->
            ExploreTile(category, Modifier.weight(1f))
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
private fun ExploreTile(category: CategoryDto, modifier: Modifier = Modifier) {
  val artwork = category.collections?.firstOrNull()
  Box(
    modifier
      .height(EXPLORE_TILE_HEIGHT)
      .clip(RoundedCornerShape(Dp.tile)),
  ) {
    ArtworkImage(
      url = artwork?.imageUrl,
      palette = artwork?.palette,
      contentDescription = category.title,
      modifier = Modifier.fillMaxSize(),
    )
    // Scrim so the title stays legible over a photograph.
    Box(
      Modifier
        .fillMaxSize()
        .background(
          Brush.verticalGradient(
            colors = listOf(Color.Transparent, Color.deepPlum.copy(alpha = 0.5f)),
          ),
        ),
    )
    Text(
      text = category.title,
      style = DeepType.displayTitle,
      color = Color.White,
      modifier = Modifier
        .align(Alignment.BottomStart)
        .padding(14.dp),
    )
  }
}

@Composable
private fun HomeSkeleton(modifier: Modifier = Modifier) {
  Column(
    modifier.padding(top = Dp.rhythm),
    verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
  ) {
    repeat(SKELETON_SHELF_COUNT) { ShelfSkeleton() }
    ExploreSkeleton()
  }
}

@Composable
private fun ShelfSkeleton(modifier: Modifier = Modifier) {
  Column(
    modifier,
    verticalArrangement = Arrangement.spacedBy(12.dp),
  ) {
    SkeletonBlock(
      modifier = Modifier
        .padding(horizontal = Dp.edge)
        .width(140.dp)
        .height(18.dp)
    )
    LazyRow(
      horizontalArrangement = Arrangement.spacedBy(12.dp),
      contentPadding = PaddingValues(horizontal = Dp.edge),
      userScrollEnabled = false,
    ) {
      items(3) {
        SkeletonBlock(
          modifier = Modifier
            .size(TILE_WIDTH)
            .clip(RoundedCornerShape(Dp.tile))
        )
      }
    }
  }
}

@Composable
private fun ExploreSkeleton(modifier: Modifier = Modifier) {
  Column(
    modifier.padding(horizontal = Dp.edge),
    verticalArrangement = Arrangement.spacedBy(14.dp),
  ) {
    SkeletonBlock(
      modifier = Modifier
        .width(100.dp)
        .height(18.dp)
    )
    repeat(EXPLORE_SKELETON_ROWS) {
      Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        SkeletonBlock(
          modifier = Modifier
            .weight(1f)
            .height(EXPLORE_TILE_HEIGHT)
            .clip(RoundedCornerShape(Dp.tile))
        )
        SkeletonBlock(
          modifier = Modifier
            .weight(1f)
            .height(EXPLORE_TILE_HEIGHT)
            .clip(RoundedCornerShape(Dp.tile))
        )
      }
    }
  }
}

/**
 * The failed state.
 *
 * It says what happened and offers a retry. It deliberately does **not** fall
 * back to bundled sample content: onboarding learned that the hard way, where
 * fixture trees shared ids and names with the real rows and a dead backend
 * rendered as a working picker.
 */
@Composable
private fun HomeFailed(
  message: String,
  onRetry: () -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(
    modifier
      .fillMaxWidth()
      .padding(horizontal = Dp.edge, vertical = Dp.rhythm),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(10.dp),
  ) {
    Text(
      stringResource(R.string.home_failed_title),
      style = DeepType.displayTitle,
      color = Color.deepPlum,
      textAlign = TextAlign.Center,
    )
    Text(
      message,
      style = DeepType.body,
      color = Color.driftGrey,
      textAlign = TextAlign.Center,
    )
    Box(
      Modifier
        .clip(RoundedCornerShape(Dp.card))
        .frostedCard(cornerRadius = Dp.card)
        .softPress()
        .clickable(onClick = onRetry)
        .padding(horizontal = 28.dp, vertical = 12.dp),
    ) {
      Text(
        stringResource(R.string.home_retry),
        style = DeepType.bodyMedium,
        color = Color.deepPlum,
      )
    }
  }
}

private val HERO_OVERLAP = 80.dp
private val TILE_WIDTH = 160.dp
private val EXPLORE_TILE_HEIGHT = 92.dp

/** Placeholder shelves shown while loading — real content decides the real count. */
private const val SKELETON_SHELF_COUNT = 2
private const val EXPLORE_SKELETON_ROWS = 2

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
      )
    }
  }
}

@Preview(showBackground = true, name = "Home skeleton")
@Composable
private fun HomeSkeletonPreview() {
  DeepTheme {
    Column(Modifier.fillMaxWidth().background(Color.moonCream)) {
      HomeSkeleton()
    }
  }
}
