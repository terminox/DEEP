package io.appbeyond.freelance.deep.feature.appshell

import androidx.activity.compose.BackHandler
import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionLayout
import androidx.compose.animation.core.SeekableTransitionState
import androidx.compose.animation.core.Transition
import androidx.compose.animation.core.rememberTransition
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.runtime.toMutableStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsound.CollectionDetailScreen
import io.appbeyond.freelance.deep.feature.deepsound.DeepSoundHomeScreen
import io.appbeyond.freelance.deep.feature.deepsound.components.MiniPlayerPill
import io.appbeyond.freelance.deep.feature.deepsound.components.MiniPlayerPillHeight
import io.appbeyond.freelance.deep.feature.deepsound.components.NowPlayingScreen
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.player.MockSoundPlayer
import io.appbeyond.freelance.deep.feature.deepsound.player.SoundPlaying
import io.appbeyond.freelance.deep.feature.deepsound.store.MockSoundLibrary
import io.appbeyond.freelance.deep.feature.deepsound.store.SoundLibrary
import io.appbeyond.freelance.deep.feature.globalpause.CollectionListScreen
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockAccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.feature.playlist.PlaylistScreen
import io.appbeyond.freelance.deep.feature.profile.SettingsScreen
import io.appbeyond.freelance.deep.feature.playlist.store.MockPlaylistStore
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistStore
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.localization.AppLanguage
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.hush
import io.appbeyond.freelance.deep.theme.settle
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/**
 * Where a tab can go. One sealed hierarchy shared by every tab: Home and Sounds
 * both push collections, so a per-tab hierarchy would only repeat them.
 */
sealed interface DeepRoute {
  data object Root : DeepRoute

  /**
   * The system settings, pushed onto the You tab's stack. iOS's
   * `YouCoordinatorView` also routes `.language` and `.dailyReminder` from
   * here; on Android those rows are UI only for now, so they have no route.
   */
  data object Settings : DeepRoute

  /** A collection's tracks — pushed from Sounds' shelves or a Home list. */
  data class Collection(val collection: SoundCollection) : DeepRoute

  /** A titled list of collections — an Explore category on Home. */
  data class CollectionList(
    val title: String,
    val collections: List<SoundCollection>,
  ) : DeepRoute
}

/**
 * What Home's root can ask of the shell. A value rather than a growing list of
 * lambdas on [MainShellCoordinator]'s `homeContent` slot, so a new way out of
 * Home does not change the slot's shape.
 */
@Immutable
data class HomeActions(
  val openDeepSession: (DeepSession) -> Unit,
  val openCollectionList: (title: String, collections: List<SoundCollection>) -> Unit,
)

/**
 * The tab shell: five tabs, each with **its own back stack**, over one bottom
 * bar — and, from week three, the one player every tab shares.
 *
 * This is the coordinator the project's rules describe — it owns navigation and
 * nothing else, and the leaf screens it routes to never host a container of their
 * own. They receive navigation as actions, passed down as plain lambdas so a
 * `@Preview` of a leaf stays hermetic.
 *
 * Styling deliberately stays out of here. Each leaf paints its own atmosphere;
 * a background placed at this level would sit behind the bar and never be seen,
 * which is a mistake the iOS side already made once and documented.
 *
 * **The player.** iOS docks its mini player in the OS tab accessory and zooms
 * Now Playing out of it. Android has no accessory, so, as settled in week two,
 * the mini player is a frosted pill floating 8dp above [DeepBottomBar] while a
 * track is loaded, and Now Playing grows out of it through a shared-element
 * transform that covers the bar. One [SeekableTransitionState] drives every
 * way in and out — a tap, the pill's swipe up, Now Playing's swipe down, and
 * predictive back — so a gesture scrubs the very animation a tap plays.
 * Screens that scroll pad their bottom by [LocalMiniPlayerClearance] so their
 * last row clears the pill.
 *
 * All of its state — the selected tab, every stack and the expansion — lives
 * only as long as it is composed. `AppRoot` drops it when the phase leaves Main
 * (log out, delete account) and composes a fresh one on the way back, so the
 * next member never opens on the last one's Settings screen.
 *
 * @param accountStore / onboardingStore the shared stores Settings writes to on
 *   the way out; flipping them is what moves `AppRoot` off this shell.
 * @param language the language Deep reads in, shown on Settings' Language row.
 * @param soundPlayer the app's one player, shared by every tab and the pill.
 * @param soundLibrary Deep Sound's shelves and lyrics.
 * @param playlistStore the member's saved sounds — the You tab's root.
 */
@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun MainShellCoordinator(
  accountStore: AccountStore,
  onboardingStore: OnboardingProgressStore,
  language: AppLanguage,
  soundPlayer: SoundPlaying,
  soundLibrary: SoundLibrary,
  playlistStore: PlaylistStore,
  modifier: Modifier = Modifier,
  onOpenDeepSession: (DeepSession) -> Unit = {},
  homeContent: @Composable (actions: HomeActions) -> Unit = {},
) {
  var selected by rememberSaveable { mutableStateOf(DeepTab.Home) }

  // One stack per tab, so switching away and back returns you where you were —
  // and so system back unwinds the tab you are actually looking at.
  var nextEntryId by remember { mutableLongStateOf(DeepTab.entries.size.toLong()) }
  val stacks: Map<DeepTab, SnapshotStateList<StackEntry>> = remember {
    DeepTab.entries.associateWith { tab ->
      listOf(StackEntry(tab.ordinal.toLong(), DeepRoute.Root)).toMutableStateList()
    }
  }
  val stack = stacks.getValue(selected)
  // Every screen in every stack keeps its saveable state — above all its
  // scroll position — while it is covered by a pushed screen or another tab,
  // the way a SwiftUI NavigationStack keeps its root alive. Without this the
  // root was rebuilt on every back and every tab switch, so opening a
  // collection from the Deep Kids shelf dropped you back at the top.
  // Keyed by each entry's own id — never by depth, or a screen still fading
  // out and the one pushed in its place would share a key and crash the
  // holder. A popped screen's state is dropped with it.
  val screenStates = rememberSaveableStateHolder()
  fun dropAbove(tab: DeepTab, depth: Int) {
    val tabStack = stacks.getValue(tab)
    while (tabStack.size > depth + 1) {
      screenStates.removeState(tabStack.last().id)
      tabStack.removeAt(tabStack.lastIndex)
    }
  }

  fun push(tab: DeepTab, route: DeepRoute) {
    stacks.getValue(tab).add(StackEntry(nextEntryId++, route))
  }
  fun pop(tab: DeepTab) {
    val tabStack = stacks.getValue(tab)
    if (tabStack.size > 1) dropAbove(tab, tabStack.lastIndex - 1)
  }

  val currentOnOpenDeepSession by rememberUpdatedState(onOpenDeepSession)
  val homeActions = remember {
    HomeActions(
      openDeepSession = { currentOnOpenDeepSession(it) },
      openCollectionList = { title, collections ->
        push(DeepTab.Home, DeepRoute.CollectionList(title, collections))
      },
    )
  }

  // Read through `derivedStateOf`, so the shell recomposes only as the pill
  // arrives or leaves — not on every play/pause or volume change.
  val playback = soundPlayer.playback.collectAsStateWithLifecycle()
  val hasTrack by remember { derivedStateOf { playback.value.hasTrack } }

  // `false` is the pill, `true` is Now Playing.
  val expansion = remember { SeekableTransitionState(false) }
  val transition = rememberTransition(expansion, label = "now-playing")
  val scope = rememberCoroutineScope()
  val expanded = expansion.currentState || expansion.targetState
  var collapseCommitted by remember { mutableStateOf(false) }

  fun expand() = scope.launch { expansion.animateTo(true) }
  fun collapse() = scope.launch { expansion.animateTo(false) }

  /** Where a drag let go: past the midpoint or flung that way, it finishes. */
  fun release(towards: Boolean, velocity: Float, flingThreshold: Float) = scope.launch {
    val committed = expansion.fraction > COMMIT_FRACTION || velocity > flingThreshold
    expansion.animateTo(if (committed) towards else !towards)
  }

  // The saved sounds are fetched as the shell opens (launch, or a fresh sign-in)
  // and on every return to the foreground — iOS's bootstrap, flow → main and
  // scene-phase seams — so a bookmark on a collection or Now Playing is right
  // before anyone visits the You tab. ON_START is replayed on registration, so
  // this also covers the first composition.
  LifecycleEventEffect(Lifecycle.Event.ON_START) {
    scope.launch { playlistStore.load() }
  }

  // A cleared player (log out) leaves nothing to show.
  LaunchedEffect(hasTrack) {
    if (!hasTrack && expansion.currentState) expansion.snapTo(false)
  }

  // Back unwinds the active tab, then falls back to Home, and only then leaves
  // the app. Anything else strands someone three tabs deep.
  BackHandler(enabled = stack.size > 1 || selected != DeepTab.Home) {
    if (stack.size > 1) pop(selected) else selected = DeepTab.Home
  }

  // Composed after the shell's handler so it wins while Now Playing is up —
  // and only while it is headed open, so once a collapse is committed the
  // next back reaches the tabs. The gesture scrubs the collapse; letting go
  // finishes it, and a cancelled gesture springs back open on a fresh
  // coroutine — this one is already over.
  PredictiveBackHandler(enabled = expanded && !collapseCommitted) { events ->
    try {
      events.collect { event -> expansion.seekTo(event.progress, targetState = false) }
    } catch (cancelled: CancellationException) {
      scope.launch { expansion.animateTo(true) }
      throw cancelled
    }
    // Committed: finish on the shell's scope, outside this handler's job, so a
    // second back press arriving mid-collapse cannot cancel it into a reopen.
    collapseCommitted = true
    scope.launch {
      try {
        expansion.animateTo(false)
      } finally {
        collapseCommitted = false
      }
    }
  }

  val flingThreshold = with(LocalDensity.current) { FLING_VELOCITY.toPx() }
  val clearance: Dp = if (hasTrack) MiniPlayerPillHeight + PILL_GAP else 0.dp

  SharedTransitionLayout(modifier.fillMaxSize()) {
    Box(Modifier.fillMaxSize()) {
      // While Now Playing is fully up it is the whole screen: the shell under it
      // leaves the accessibility tree, as iOS's full-screen presentation does.
      val covered = expansion.currentState && expansion.targetState
      Column(
        Modifier
          .fillMaxSize()
          .then(if (covered) Modifier.clearAndSetSemantics {} else Modifier),
      ) {
        Box(Modifier.weight(1f)) {
          CompositionLocalProvider(LocalMiniPlayerClearance provides clearance) {
            AnimatedContent(
              targetState = selected to stack.last(),
              transitionSpec = { fadeIn(exhale()) togetherWith fadeOut(exhale()) },
              label = "tab-content",
            ) { (tab, entry) ->
              screenStates.SaveableStateProvider(entry.id) {
                when (val route = entry.route) {
                  DeepRoute.Root -> when (tab) {
                    DeepTab.Home -> homeContent(homeActions)
                    DeepTab.Sounds -> DeepSoundHomeScreen(
                      library = soundLibrary,
                      onOpenCollection = { push(DeepTab.Sounds, DeepRoute.Collection(it)) },
                      onOpenDeepSession = onOpenDeepSession,
                    )
                    DeepTab.Garden -> TabPlaceholderScreen(DeepTab.Garden)
                    DeepTab.Compassion -> TabPlaceholderScreen(DeepTab.Compassion)
                    DeepTab.You -> PlaylistScreen(
                      playlistStore = playlistStore,
                      player = soundPlayer,
                      onOpenSettings = { push(DeepTab.You, DeepRoute.Settings) },
                      onExploreDeepSound = { selected = DeepTab.Sounds },
                    )
                  }

                  DeepRoute.Settings -> SettingsScreen(
                    accountStore = accountStore,
                    onboardingStore = onboardingStore,
                    language = language,
                    onBack = { pop(DeepTab.You) },
                  )

                  is DeepRoute.Collection -> CollectionDetailScreen(
                    collection = route.collection,
                    player = soundPlayer,
                    playlistStore = playlistStore,
                    onBack = { pop(tab) },
                  )

                  is DeepRoute.CollectionList -> CollectionListScreen(
                    title = route.title,
                    collections = route.collections,
                    onOpenCollection = { push(tab, DeepRoute.Collection(it)) },
                    onBack = { pop(tab) },
                  )
                }
              }
            }
          }

          // The pill: in only while a track is loaded, and out of the way while
          // it has grown into Now Playing.
          MiniPlayerDock(
            visible = hasTrack,
            transition = transition,
            modifier = Modifier.align(Alignment.BottomCenter),
          ) {
            MiniPlayerPill(
              player = soundPlayer,
              onExpand = { expand() },
              modifier = Modifier
                .padding(horizontal = Dp.edge)
                .fillMaxWidth()
                .sharedBounds(
                  sharedContentState = rememberSharedContentState(PLAYER_KEY),
                  animatedVisibilityScope = this,
                  clipInOverlayDuringTransition = OverlayClip(RoundedCornerShape(Dp.chip)),
                ),
              artworkModifier = Modifier.sharedElement(
                sharedContentState = rememberSharedContentState(ARTWORK_KEY),
                animatedVisibilityScope = this,
              ),
              onDragUp = { fraction ->
                scope.launch { expansion.seekTo(fraction, targetState = true) }
              },
              onDragUpEnd = { velocity -> release(towards = true, velocity, flingThreshold) },
            )
          }
        }

        DeepBottomBar(
          selected = selected,
          onSelect = { tab ->
            // Re-tapping the tab you are on pops it to root, the way it does on iOS.
            if (tab == selected) {
              dropAbove(tab, 0)
            } else {
              selected = tab
            }
          },
        )
      }

      // Drawn after the bar, so Now Playing covers it as iOS's full-screen
      // presentation does.
      transition.AnimatedVisibility(
        visible = { open -> open },
        enter = fadeIn(hush()),
        exit = fadeOut(hush()),
      ) {
        NowPlayingScreen(
          player = soundPlayer,
          playlistStore = playlistStore,
          library = soundLibrary,
          onCollapse = { collapse() },
          modifier = Modifier
            .fillMaxSize()
            .sharedBounds(
              sharedContentState = rememberSharedContentState(PLAYER_KEY),
              animatedVisibilityScope = this,
            ),
          artworkModifier = Modifier.sharedElement(
            sharedContentState = rememberSharedContentState(ARTWORK_KEY),
            animatedVisibilityScope = this,
          ),
          onDragDown = { fraction ->
            scope.launch { expansion.seekTo(fraction, targetState = false) }
          },
          onDragDownEnd = { velocity -> release(towards = false, velocity, flingThreshold) },
        )
      }
    }
  }
}

/**
 * Where the pill sits: in only while a track is loaded, and faded out of the
 * way while it has grown into Now Playing. Its own function so the
 * `AnimatedVisibility` here is the plain one — inside the shell's `Column`, the
 * `ColumnScope` overload would be picked up instead.
 */
@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
private fun MiniPlayerDock(
  visible: Boolean,
  transition: Transition<Boolean>,
  modifier: Modifier = Modifier,
  pill: @Composable AnimatedVisibilityScope.() -> Unit,
) {
  AnimatedVisibility(
    visible = visible,
    modifier = modifier,
    enter = fadeIn(settle()) + slideInVertically(settle()) { it / 2 },
    exit = fadeOut(hush()) + slideOutVertically(hush()) { it / 2 },
  ) {
    transition.AnimatedVisibility(
      visible = { open -> !open },
      enter = fadeIn(hush()),
      exit = fadeOut(hush()),
      content = pill,
    )
  }
}

/** What the tab content animates between: a tab's top route and how deep it sits. */
/**
 * One screen on a tab's stack. The id, unique for the shell's lifetime, is what
 * the screen's saved state is keyed by — two pushes of equal routes are still
 * two screens.
 */
private data class StackEntry(val id: Long, val route: DeepRoute)

private const val PLAYER_KEY = "now-playing"
private const val ARTWORK_KEY = "now-playing-artwork"

/**
 * Room the pill claims above the bar, for [LocalMiniPlayerClearance]. The pill
 * itself rests on the bar's layout edge: [DeepBottomBar] paints a 12dp bloom
 * above its visible edge, and that band is what reads as week two's 8dp gap —
 * padding on top of it measured ~18dp on screen.
 */
private val PILL_GAP = 8.dp

/** Past this share of the way, a released drag finishes rather than springs back. */
private const val COMMIT_FRACTION = 0.35f

/** A release faster than this in the drag's direction finishes it regardless of distance. */
private val FLING_VELOCITY = 800.dp

@Preview(showBackground = true)
@Composable
private fun MainShellCoordinatorPreview() {
  DeepTheme {
    MainShellCoordinator(
      accountStore = MockAccountStore.emailUser,
      onboardingStore = MockOnboardingProgressStore.fresh,
      language = AppLanguage.English,
      soundPlayer = remember { MockSoundPlayer.playing() },
      soundLibrary = remember { MockSoundLibrary.loaded },
      playlistStore = MockPlaylistStore.sample,
      homeContent = { TabPlaceholderScreen(DeepTab.Home) },
    )
  }
}
