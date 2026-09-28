package io.appbeyond.freelance.deep.feature.deepsound

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.layout
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsound.components.BreatheHeroCard
import io.appbeyond.freelance.deep.feature.deepsound.components.CollectionCarousel
import io.appbeyond.freelance.deep.feature.deepsound.components.SoundShelvesSkeleton
import io.appbeyond.freelance.deep.feature.deepsound.components.rememberBalancingBreath
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundShelf
import io.appbeyond.freelance.deep.feature.deepsound.store.MockSoundLibrary
import io.appbeyond.freelance.deep.feature.deepsound.store.SoundLibrary
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.CollapsibleHomeHeader
import io.appbeyond.freelance.deep.shared.components.HeroRefreshable
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.components.LoopingVideoView
import io.appbeyond.freelance.deep.shared.components.StretchyHero
import io.appbeyond.freelance.deep.shared.components.rememberHeroPull
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softPress
import kotlinx.coroutines.CancellationException

// MARK: - Constants

/** The video sky's resting height — iOS's `heroHeight: 320`. */
private val HERO_HEIGHT = 320.dp

/** How far the content rides up over the hero — iOS's `heroOverlap: 80`. */
private val HERO_OVERLAP = 80.dp

private val FAILED_SPACING = 14.dp
private val FAILED_PADDING_VERTICAL = 48.dp
private val RETRY_PADDING_HORIZONTAL = 22.dp
private val RETRY_PADDING_VERTICAL = 12.dp

// MARK: - Load state

/**
 * What the shelves are showing. [Failed] is only ever reached with nothing on
 * screen: a refresh that fails over [Loaded] shelves keeps them, silently — a
 * list that was fine a moment ago is worth more than an error.
 */
private sealed interface ShelvesLoad {
  data object Loading : ShelvesLoad
  data class Loaded(val shelves: List<SoundShelf>) : ShelvesLoad
  data object Failed : ShelvesLoad
}

/**
 * One fetch of the home shelves — iOS's `DeepSoundHomeView.load()`. The
 * skeleton only returns when there is nothing to keep on screen.
 */
private suspend fun loadShelves(library: SoundLibrary, state: MutableState<ShelvesLoad>) {
  if (state.value !is ShelvesLoad.Loaded) state.value = ShelvesLoad.Loading
  state.value = try {
    ShelvesLoad.Loaded(library.shelves())
  } catch (e: CancellationException) {
    throw e
  } catch (e: Exception) {
    state.value as? ShelvesLoad.Loaded ?: ShelvesLoad.Failed
  }
}

// MARK: - Screen

/**
 * The Deep Sound home — one scroll combining a stretchy video sky, the Breathe
 * doorway into Deep Session, and the category shelves fetched from the backend.
 *
 * Ported from Deep/Deep/Features/DeepSound/Components/DeepSoundHomeView.swift.
 * The Compose shape of `.collapsibleHomeHeader` and `.heroRefreshable` is two
 * containers — [HeroRefreshable] outermost, so its cue draws over the header;
 * [CollapsibleHomeHeader] inside it, wrapping only the list so its blur never
 * reaches the atmosphere behind. A pull reloads the shelves.
 *
 * A leaf screen: it paints its own [AtmosphereBackground] (in a coordinator it
 * would hide behind the navigation container) and hosts no navigation — the
 * coordinator hands it [onOpenCollection] and [onOpenDeepSession], the
 * lambdas iOS reads as `openCollection` / `openDeepSession` from the
 * environment.
 *
 * The bottom inset is iOS's `.rhythm` of breathing room plus
 * [LocalMiniPlayerClearance], which the shell provides while a track is loaded.
 *
 * @param library the content seam; the shelves load once per [library] and on
 *   every pull.
 * @param onOpenCollection asks the coordinator to push a collection's detail.
 * @param onOpenDeepSession asks the coordinator to push the session threshold.
 */
@Composable
fun DeepSoundHomeScreen(
  library: SoundLibrary,
  onOpenCollection: (SoundCollection) -> Unit,
  onOpenDeepSession: (DeepSession) -> Unit,
  modifier: Modifier = Modifier,
) {
  // Rebuilt on the way back from a collection or another tab, the screen
  // reopens on the shelves it already had — no skeleton, and rows for the
  // restored scroll position to land on — and leaves refreshing to the pull.
  val load = remember(library) {
    mutableStateOf<ShelvesLoad>(library.cachedShelves?.let(ShelvesLoad::Loaded) ?: ShelvesLoad.Loading)
  }
  var attempt by remember { mutableIntStateOf(0) }

  LaunchedEffect(library, attempt) {
    if (attempt > 0 || load.value !is ShelvesLoad.Loaded) loadShelves(library, load)
  }

  val listState = rememberLazyListState()
  val (pull, nestedScroll) = rememberHeroPull(listState)
  val session = rememberBalancingBreath()
  val bottomInset = Dp.rhythm + LocalMiniPlayerClearance.current

  HeroRefreshable(
    pull = pull,
    onRefresh = { loadShelves(library, load) },
    modifier = modifier,
  ) {
    Box(
      Modifier
        .fillMaxSize()
        .background(Color.moonCream),
    ) {
      AtmosphereBackground()

      CollapsibleHomeHeader(
        title = stringResource(R.string.deepsound_title),
        subtitle = stringResource(R.string.deepsound_subtitle),
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
            StretchyHero(pull = pull, listState = listState, height = HERO_HEIGHT) {
              LoopingVideoView(resource = R.raw.sky, modifier = Modifier.fillMaxSize())
            }
          }

          // The content rides up over the hero's feathered foot, which is what
          // makes the two read as one surface. Only this first item rises;
          // everything after simply follows it.
          item(key = "breathe") {
            BreatheHeroCard(
              session = session,
              onOpen = onOpenDeepSession,
              modifier = Modifier
                .riseOver(HERO_OVERLAP)
                .padding(horizontal = Dp.edge),
            )
          }

          when (val current = load.value) {
            ShelvesLoad.Loading -> item(key = "skeleton") {
              SoundShelvesSkeleton(
                Modifier
                  .animateItem(fadeInSpec = bloom(), fadeOutSpec = bloom(), placementSpec = null)
                  .padding(top = Dp.rhythm),
              )
            }

            ShelvesLoad.Failed -> item(key = "failed") {
              ShelvesFailed(
                onRetry = { attempt += 1 },
                modifier = Modifier
                  .animateItem(fadeInSpec = bloom(), fadeOutSpec = bloom(), placementSpec = null)
                  .padding(top = Dp.rhythm),
              )
            }

            is ShelvesLoad.Loaded -> items(current.shelves, key = { "shelf-${it.id}" }) { shelf ->
              CollectionCarousel(
                title = shelf.title,
                collections = shelf.collections,
                onOpenCollection = onOpenCollection,
                modifier = Modifier
                  .animateItem(fadeInSpec = bloom(), fadeOutSpec = bloom(), placementSpec = null)
                  .padding(top = Dp.rhythm),
              )
            }
          }
        }
      }
    }
  }
}

/**
 * Pulls the element up by [overlap] *and* gives that height back, the way
 * SwiftUI's negative top padding does — so the next item starts right under
 * this one's visible edge, not [overlap] further down as `Modifier.offset`
 * would leave it.
 */
private fun Modifier.riseOver(overlap: Dp): Modifier = layout { measurable, constraints ->
  val placeable = measurable.measure(constraints)
  val rise = overlap.roundToPx()
  layout(placeable.width, (placeable.height - rise).coerceAtLeast(0)) {
    placeable.place(0, -rise)
  }
}

/**
 * The first-load failure: what happened, and a frosted "Try again" chip. No
 * bundled fallback shelves — fixture content that looks real makes a dead
 * backend read as a working one.
 */
@Composable
private fun ShelvesFailed(onRetry: () -> Unit, modifier: Modifier = Modifier) {
  Column(
    modifier
      .fillMaxWidth()
      .padding(horizontal = Dp.edge, vertical = FAILED_PADDING_VERTICAL),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(FAILED_SPACING),
  ) {
    Text(
      stringResource(R.string.deepsound_failed),
      style = DeepType.body,
      color = Color.driftGrey,
      textAlign = TextAlign.Center,
    )
    Box(
      Modifier
        .softPress()
        .frostedCard(cornerRadius = Dp.chip)
        .clickable(
          interactionSource = remember { MutableInteractionSource() },
          indication = null,
          role = Role.Button,
          onClick = onRetry,
        )
        .padding(horizontal = RETRY_PADDING_HORIZONTAL, vertical = RETRY_PADDING_VERTICAL),
    ) {
      Text(
        stringResource(R.string.deepsound_retry),
        style = DeepType.bodyMedium,
        color = Color.deepPlum,
      )
    }
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Deep Sound — Home")
@Composable
private fun DeepSoundHomePreview() {
  DeepTheme {
    // Remembered: the companion getters build a fresh mock each read, and a
    // new library restarts the load.
    DeepSoundHomeScreen(
      library = remember { MockSoundLibrary.loaded },
      onOpenCollection = {},
      onOpenDeepSession = {},
    )
  }
}

@Preview(showBackground = true, name = "Deep Sound — Failed")
@Composable
private fun DeepSoundHomeFailedPreview() {
  DeepTheme {
    DeepSoundHomeScreen(
      library = remember { MockSoundLibrary.failing },
      onOpenCollection = {},
      onOpenDeepSession = {},
    )
  }
}

@Preview(showBackground = true, name = "Shelves failed")
@Composable
private fun ShelvesFailedPreview() {
  DeepTheme {
    Box(Modifier.background(Color.moonCream)) {
      ShelvesFailed(onRetry = {})
    }
  }
}
