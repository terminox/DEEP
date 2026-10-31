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
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.listSaver
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
import io.appbeyond.freelance.deep.feature.deepsession.DeepSessionIntroScreen
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsound.CollectionDetailScreen
import io.appbeyond.freelance.deep.feature.deepsound.DeepSoundHomeScreen
import io.appbeyond.freelance.deep.feature.deepsound.components.ListenNoticeAnnouncer
import io.appbeyond.freelance.deep.feature.deepsound.components.MiniPlayerPill
import io.appbeyond.freelance.deep.feature.deepsound.components.MiniPlayerPillHeight
import io.appbeyond.freelance.deep.feature.deepsound.components.NowPlayingScreen
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.player.MockSoundPlayer
import io.appbeyond.freelance.deep.feature.deepsound.player.SoundPlaying
import io.appbeyond.freelance.deep.feature.rewards.store.ListenReporting
import io.appbeyond.freelance.deep.feature.rewards.store.MockListenReporter
import io.appbeyond.freelance.deep.feature.deepsound.store.MockSoundLibrary
import io.appbeyond.freelance.deep.feature.deepsound.store.SoundLibrary
import io.appbeyond.freelance.deep.feature.globalpause.CollectionListScreen
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockAccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockOnboardingProgressStore
import io.appbeyond.freelance.deep.feature.onboarding.store.OnboardingProgressStore
import io.appbeyond.freelance.deep.feature.playlist.PlaylistScreen
import io.appbeyond.freelance.deep.feature.profile.LanguageScreen
import io.appbeyond.freelance.deep.feature.profile.SettingsScreen
import io.appbeyond.freelance.deep.feature.reminders.DailyReminderScreen
import io.appbeyond.freelance.deep.feature.reminders.store.MockReminderScheduler
import io.appbeyond.freelance.deep.feature.reminders.store.ReminderPermission
import io.appbeyond.freelance.deep.feature.reminders.store.ReminderStore
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import java.time.Clock
import java.time.ZoneId
import io.appbeyond.freelance.deep.feature.playlist.store.MockPlaylistStore
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistStore
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.components.LocalTabReselection
import io.appbeyond.freelance.deep.shared.localization.AppLanguage
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.hush
import io.appbeyond.freelance.deep.theme.settle
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

/**
 * Where a tab can go. One sealed hierarchy shared by every tab: Home and Sounds
 * both push collections, so a per-tab hierarchy would only repeat them.
 */
sealed interface DeepRoute {
  data object Root : DeepRoute

  /** The system settings, pushed onto the You tab's stack. */
  data object Settings : DeepRoute

  /** The language picker, pushed from Settings — iOS's `.language`. */
  data object Language : DeepRoute

  /** The daily reminder, pushed from Settings — iOS's `.dailyReminder`. */
  data object DailyReminder : DeepRoute

  /**
   * A cause in full, on the Compassion tab's stack. **Parked**, as iOS parks
   * `openCategory`: nothing pushes it while giving happens on the cause cards.
   */
  data class CompassionCause(val causeId: String) : DeepRoute

  /** Fuku's Lounge, pushed from Home's lounge card — iOS's `openFukuLounge`. */
  data object FukuLounge : DeepRoute

  /**
   * A DEEP Session's threshold, pushed onto whichever tab's entry card opened
   * it — iOS's `openDeepSession`, so the tab bar and mini player stay. Begin
   * lifts the practice itself over the whole shell, from `AppRoot`.
   */
  data class SessionThreshold(val session: DeepSession) : DeepRoute

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
  val openCollection: (SoundCollection) -> Unit,
  val openCollectionList: (title: String, collections: List<SoundCollection>) -> Unit,
  val openFukuLounge: () -> Unit = {},
)

/**
 * What Settings' two preference screens can ask of the app: adopt a language,
 * and switch or re-time the daily reminder. A value, so the shell's shape
 * doesn't grow a lambda per action.
 */
@Immutable
data class PreferenceActions(
  val selectLanguage: (AppLanguage) -> Unit,
  val enableReminder: suspend (prompt: suspend () -> Boolean) -> ReminderPermission,
  val setReminderTime: suspend (hour: Int, minute: Int) -> Unit,
  val disableReminder: suspend () -> Unit,
) {
  companion object {
    /** Does nothing — previews. */
    val none = PreferenceActions(
      selectLanguage = {},
      enableReminder = { ReminderPermission.Granted },
      setReminderTime = { _, _ -> },
      disableReminder = {},
    )
  }
}

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
 * @param language the language DEEP reads in, shown on Settings' Language row
 *   and checked on the picker.
 * @param reminderStore the daily reminder's settings, for Settings' row and
 *   the reminder screen.
 * @param preferences the language and reminder actions those screens take.
 * @param soundPlayer the app's one player, shared by every tab and the pill.
 * @param listenReporter a finished track's heart, which the pill and Now
 *   Playing swap into their subtitle line; announced to TalkBack here, once.
 * @param soundLibrary DEEP Sound's shelves and lyrics.
 * @param playlistStore the member's saved sounds — the You tab's root.
 * @param flushBeforeLogOut / resetAccountState the rewards side of
 *   Settings' log out and account deletion, handed straight through.
 * @param homeContent / gardenContent the Home and Mind Garden roots. Slots, so
 *   the shell carries none of their stores; each is handed the same
 *   [HomeActions] — the Garden's daily practice card opens a DEEP Session.
 * @param compassionContent the Compassion root, handed the (parked) way into a
 *   cause's detail; [compassionCauseContent] draws that detail.
 * @param fukuLoungeContent Fuku's Lounge, pushed on Home's stack, handed the
 *   way into the live session ([onOpenGlobalPause]) and back.
 * @param onBeginDeepSession Begin on a session threshold, with the practice at
 *   the chosen length: `AppRoot` presents it over the whole shell.
 * @param deepSessionRunning true while that practice covers the shell — the
 *   threshold answers with its half of the lift.
 * @param miniPlayerSuppressed true while a practice covers the shell — a DEEP
 *   Session or the live Global Pause (settled in week 2): the pill leaves
 *   rather than wait under the cover.
 */
@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun MainShellCoordinator(
  accountStore: AccountStore,
  onboardingStore: OnboardingProgressStore,
  language: AppLanguage,
  reminderStore: ReminderStore,
  preferences: PreferenceActions,
  soundPlayer: SoundPlaying,
  listenReporter: ListenReporting,
  soundLibrary: SoundLibrary,
  playlistStore: PlaylistStore,
  flushBeforeLogOut: suspend () -> Boolean,
  resetAccountState: suspend () -> Unit,
  modifier: Modifier = Modifier,
  onBeginDeepSession: (DeepSession) -> Unit = {},
  deepSessionRunning: Boolean = false,
  homeContent: @Composable (actions: HomeActions) -> Unit = {},
  gardenContent: @Composable (actions: HomeActions) -> Unit = {},
  compassionContent: @Composable (openCause: (String) -> Unit) -> Unit = {},
  compassionCauseContent: @Composable (causeId: String, onBack: () -> Unit) -> Unit = { _, _ -> },
  onOpenGlobalPause: () -> Unit = {},
  fukuLoungeContent: @Composable (onJoin: () -> Unit, onBack: () -> Unit) -> Unit = { _, _ -> },
  miniPlayerSuppressed: Boolean = false,
) {
  val reminderState by reminderStore.state.collectAsStateWithLifecycle()
  var selected by rememberSaveable { mutableStateOf(DeepTab.Home) }

  // One stack per tab, so switching away and back returns you where you were —
  // and so system back unwinds the tab you are actually looking at.
  // Saveable, so an activity recreate — the one a language switch causes,
  // above all — returns the member to the screen they were on (QA round 1,
  // B9: Settings → Language used to drop back to the You tab's root).
  var nextEntryId by rememberSaveable { mutableLongStateOf(DeepTab.entries.size.toLong()) }
  val stacks: Map<DeepTab, SnapshotStateList<StackEntry>> = rememberSaveable(saver = TabStacksSaver) {
    DeepTab.entries.associateWith { tab ->
      listOf(StackEntry(tab.ordinal.toLong(), DeepRoute.Root)).toMutableStateList()
    }
  }
  val stack = stacks.getValue(selected)
  // Every screen in every stack keeps its saveable state — above all its
  // scroll position — while it is covered by a pushed screen or another tab,
  // the way a SwiftUI NavigationStack keeps its root alive. Without this the
  // root was rebuilt on every back and every tab switch, so opening a
  // collection from the DEEP Kids shelf dropped you back at the top.
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

  /**
   * Pushes a session's threshold onto the tab in front — the one whose entry
   * card was tapped. A second tap landing before the first push has drawn is
   * dropped rather than stacking two thresholds.
   */
  fun openSessionThreshold(session: DeepSession) {
    val tabStack = stacks.getValue(selected)
    if (tabStack.last().route !is DeepRoute.SessionThreshold) {
      push(selected, DeepRoute.SessionThreshold(session))
    }
  }

  val homeActions = remember {
    HomeActions(
      openDeepSession = { openSessionThreshold(it) },
      openCollection = { push(DeepTab.Home, DeepRoute.Collection(it)) },
      openCollectionList = { title, collections ->
        push(DeepTab.Home, DeepRoute.CollectionList(title, collections))
      },
      openFukuLounge = { push(DeepTab.Home, DeepRoute.FukuLounge) },
    )
  }

  // Read through `derivedStateOf`, so the shell recomposes only as the pill
  // arrives or leaves — not on every play/pause or volume change.
  val playback = soundPlayer.playback.collectAsStateWithLifecycle()
  val hasTrack by remember { derivedStateOf { playback.value.hasTrack } }
  val suppressed by rememberUpdatedState(miniPlayerSuppressed)
  val showsPill by remember { derivedStateOf { hasTrack && !suppressed } }

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

  // A listen's heart is spoken here, once, whichever of the pill and Now
  // Playing is showing it.
  ListenNoticeAnnouncer(listenReporter)

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

  // Re-tapping the tab in front scrolls its front-most screen back to the top
  // and never pops — iOS's `scrollSelectedTabToTop`. Each screen is handed only
  // its own reselections (keyed by its stack entry), through
  // [LocalTabReselection]; a screen that scrolls opts in with
  // `ScrollToTopOnReselect`, and one that doesn't simply ignores them.
  val reselections = remember { MutableSharedFlow<Long>(extraBufferCapacity = 1) }

  val flingThreshold = with(LocalDensity.current) { FLING_VELOCITY.toPx() }
  val clearance: Dp = if (showsPill) MiniPlayerPillHeight + PILL_GAP else 0.dp

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
              val reselected = remember(entry.id) {
                reselections.filter { it == entry.id }.map { }
              }
              screenStates.SaveableStateProvider(entry.id) {
                CompositionLocalProvider(LocalTabReselection provides reselected) {
                  when (val route = entry.route) {
                    DeepRoute.Root -> when (tab) {
                      DeepTab.Home -> homeContent(homeActions)
                      DeepTab.Sounds -> DeepSoundHomeScreen(
                        library = soundLibrary,
                        onOpenCollection = { push(DeepTab.Sounds, DeepRoute.Collection(it)) },
                        onOpenDeepSession = { openSessionThreshold(it) },
                      )
                      DeepTab.Garden -> gardenContent(homeActions)
                      DeepTab.Compassion -> compassionContent { causeId ->
                        push(DeepTab.Compassion, DeepRoute.CompassionCause(causeId))
                      }
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
                      reminder = reminderState.reminder,
                      flushBeforeLogOut = flushBeforeLogOut,
                      resetAccountState = resetAccountState,
                      onOpenLanguage = { push(DeepTab.You, DeepRoute.Language) },
                      onOpenReminder = { push(DeepTab.You, DeepRoute.DailyReminder) },
                      onBack = { pop(DeepTab.You) },
                    )

                    DeepRoute.Language -> LanguageScreen(
                      selection = language,
                      onSelect = preferences.selectLanguage,
                      onBack = { pop(DeepTab.You) },
                    )

                    DeepRoute.DailyReminder -> DailyReminderScreen(
                      store = reminderStore,
                      enable = preferences.enableReminder,
                      setTime = preferences.setReminderTime,
                      disable = preferences.disableReminder,
                      onBack = { pop(DeepTab.You) },
                    )

                    is DeepRoute.CompassionCause -> compassionCauseContent(route.causeId) { pop(tab) }

                    DeepRoute.FukuLounge -> fukuLoungeContent(onOpenGlobalPause) { pop(tab) }

                    is DeepRoute.SessionThreshold -> DeepSessionIntroScreen(
                      session = route.session,
                      onBegin = onBeginDeepSession,
                      onBack = { pop(tab) },
                      isRunning = deepSessionRunning,
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
          }

          // The pill: in only while a track is loaded, and out of the way while
          // it has grown into Now Playing.
          MiniPlayerDock(
            visible = showsPill,
            transition = transition,
            modifier = Modifier.align(Alignment.BottomCenter),
          ) {
            MiniPlayerPill(
              player = soundPlayer,
              listenReporter = listenReporter,
              onExpand = { expand() },
              modifier = Modifier
                .padding(horizontal = Dp.edge)
                .fillMaxWidth()
                .sharedBounds(
                  sharedContentState = rememberSharedContentState(PLAYER_KEY),
                  animatedVisibilityScope = this,
                  clipInOverlayDuringTransition = OverlayClip(RoundedCornerShape(Dp.chip)),
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
            // Re-tapping the tab you are on scrolls its front-most screen to
            // the top, the way iOS's `scrollSelectedTabToTop` does — it never
            // pops; back does that. Not underneath Now Playing.
            if (tab != selected) {
              selected = tab
            } else if (!expanded) {
              reselections.tryEmit(stack.last().id)
            }
          },
        )
      }

      // Drawn after the bar, so Now Playing covers it as iOS's full-screen
      // presentation does. The whole screen grows out of the whole pill — iOS's
      // zoom from the bar. Its photograph is full-bleed, so it is no longer
      // matched to the pill's thumbnail on its own: a shared element draws in
      // the overlay above everything, and would cover the scrims and controls
      // for the length of the morph, then drop beneath them as it landed.
      transition.AnimatedVisibility(
        visible = { open -> open },
        enter = fadeIn(hush()),
        exit = fadeOut(hush()),
      ) {
        NowPlayingScreen(
          player = soundPlayer,
          listenReporter = listenReporter,
          playlistStore = playlistStore,
          library = soundLibrary,
          onCollapse = { collapse() },
          modifier = Modifier
            .fillMaxSize()
            .sharedBounds(
              sharedContentState = rememberSharedContentState(PLAYER_KEY),
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

/**
 * The tab stacks across an activity recreate. Each tab saves as one string of
 * `id route` lines. The routes that carry only an id round-trip; a collection
 * or a collection list carries its whole payload, so a stack is cut just below
 * the first of those — the member lands on the screen that pushed it.
 */
private val TabStacksSaver: Saver<Map<DeepTab, SnapshotStateList<StackEntry>>, Any> = listSaver(
  save = { stacks ->
    DeepTab.entries.map { tab ->
      stacks.getValue(tab)
        .map { entry -> entry.route.savedKey()?.let { "${entry.id} $it" } }
        .takeWhile { it != null }
        .joinToString("\n")
    }
  },
  restore = { saved ->
    DeepTab.entries.mapIndexed { index, tab ->
      val entries = saved.getOrNull(index).orEmpty()
        .lineSequence()
        .mapNotNull { line ->
          val id = line.substringBefore(' ').toLongOrNull() ?: return@mapNotNull null
          routeOf(line.substringAfter(' '))?.let { StackEntry(id, it) }
        }
        .toList()
        .ifEmpty { listOf(StackEntry(tab.ordinal.toLong(), DeepRoute.Root)) }
      tab to entries.toMutableStateList()
    }.toMap()
  },
)

private const val CAUSE_PREFIX = "cause:"
private const val SESSION_PREFIX = "session:"

/** This route as a saved key, or null when it can't be rebuilt from one. */
private fun DeepRoute.savedKey(): String? = when (this) {
  DeepRoute.Root -> "root"
  DeepRoute.Settings -> "settings"
  DeepRoute.Language -> "language"
  DeepRoute.DailyReminder -> "reminder"
  DeepRoute.FukuLounge -> "lounge"
  is DeepRoute.CompassionCause -> CAUSE_PREFIX + causeId
  is DeepRoute.SessionThreshold -> SESSION_PREFIX + session.id
  is DeepRoute.Collection, is DeepRoute.CollectionList -> null
}

private fun routeOf(key: String): DeepRoute? = when {
  key == "root" -> DeepRoute.Root
  key == "settings" -> DeepRoute.Settings
  key == "language" -> DeepRoute.Language
  key == "reminder" -> DeepRoute.DailyReminder
  key == "lounge" -> DeepRoute.FukuLounge
  key.startsWith(CAUSE_PREFIX) -> DeepRoute.CompassionCause(key.removePrefix(CAUSE_PREFIX))
  // Only the pattern survives: the threshold titles the practice from
  // resources and stretches it to the remembered length itself.
  key.startsWith(SESSION_PREFIX) -> DeepRoute.SessionThreshold(
    DeepSession(id = key.removePrefix(SESSION_PREFIX), title = "", tagline = "", cycles = 1),
  )
  else -> null
}

private const val PLAYER_KEY = "now-playing"

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
      reminderStore = remember {
        ReminderStore(MockReminderScheduler(), InMemoryBlobStore(), Clock.systemDefaultZone()) { ZoneId.systemDefault() }
      },
      preferences = PreferenceActions.none,
      soundPlayer = remember { MockSoundPlayer.playing() },
      listenReporter = remember { MockListenReporter() },
      soundLibrary = remember { MockSoundLibrary.loaded },
      playlistStore = MockPlaylistStore.sample,
      flushBeforeLogOut = { true },
      resetAccountState = {},
      homeContent = { TabPlaceholderScreen(DeepTab.Home) },
    )
  }
}
