package io.appbeyond.freelance.deep.feature.playlist

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.PlayerIcons
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.feature.deepsound.components.SoundActionButton
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundPlayback
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import io.appbeyond.freelance.deep.feature.deepsound.player.MockSoundPlayer
import io.appbeyond.freelance.deep.feature.deepsound.player.SoundPlaying
import io.appbeyond.freelance.deep.feature.playlist.components.PlaylistSkeleton
import io.appbeyond.freelance.deep.feature.playlist.components.PlaylistTrackRow
import io.appbeyond.freelance.deep.feature.playlist.store.MockPlaylistStore
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistFixtures
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistState
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistStore
import io.appbeyond.freelance.deep.feature.profile.HeaderIconButton
import io.appbeyond.freelance.deep.feature.profile.ProfileIcons
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softPress
import kotlinx.coroutines.launch
import kotlin.random.Random

// MARK: - Constants

/** iOS `PinnedHomeHeader`: `.padding(.top, 6)` / `.padding(.bottom, 10)` — as week 2's You header. */
private val HEADER_PADDING_TOP = 6.dp
private val HEADER_PADDING_BOTTOM = 10.dp
private val HEADER_SPACING = 12.dp
private val HEADER_TITLE_SPACING = 2.dp

/** Between saved rows — iOS's `LazyVStack(spacing: 14)`. */
private val ROW_GAP = 14.dp

/** Between Play and Shuffle — iOS's `HStack(spacing: 12)`. */
private val ACTIONS_SPACING = 12.dp

/** Content arriving blooms up from here — DESIGN.md's "scale 0.92 to 1.0". */
private const val BLOOM_FROM_SCALE = 0.92f

/**
 * The invitation's air, so it lands as a note in an empty room rather than a
 * headline pinned under the header — iOS's `.padding(.top, 72)`.
 */
private val INVITATION_TOP_AIR = 72.dp
private val INVITATION_SPACING = 18.dp
private val INVITATION_TEXT_SPACING = 6.dp

/** Held short of the full width: edge to edge, one grey line reads as a banner — iOS's `maxWidth: 260`. */
private val INVITATION_BODY_MAX_WIDTH = 260.dp

/** The failure note — iOS's `VStack(spacing: 14)`, `.padding(.vertical, 48)`. */
private val FAILURE_SPACING = 14.dp
private val FAILURE_PADDING_VERTICAL = 48.dp

/** The frosted chip button — iOS's `.padding(.horizontal, 22)` / `.padding(.vertical, 12)`. */
private val CHIP_PADDING_HORIZONTAL = 22.dp
private val CHIP_PADDING_VERTICAL = 12.dp

// MARK: - Screen

/**
 * The You tab's home: the sounds this listener saved, with Settings behind the
 * header's trailing control. Ported from
 * `Deep/Deep/Features/Playlist/Components/PlaylistView.swift`; replaces week
 * 2's `YouScreen` placeholder as the tab's root and keeps its header's shape —
 * the wordmark title, a caption beneath, the frosted control trailing.
 *
 * No hero. The other tabs open on a full-bleed video because each has a mood
 * to set; a playlist is a list you came to use, and a tall sky would push the
 * first sound below the fold. This is the leaf, so it owns its screen-level
 * styling — [AtmosphereBackground] sits behind the list here rather than in
 * the shell, where the tab container would hide it.
 *
 * Tapping a sound — or Play, or Shuffle — starts the whole saved list as the
 * queue from that sound. Each entry carries its own collection, so the artwork
 * and origin line change track by track. iOS gates premium sounds behind a
 * note here; Android plays everything, a deliberate divergence.
 *
 * A leaf: navigation arrives as [onOpenSettings] (and [onExploreDeepSound],
 * the empty state's way out — `null` hides that button), and the shell owns
 * the stack it pushes onto. Bottom padding adds [LocalMiniPlayerClearance] so
 * the last sound clears the floating mini player.
 */
@Composable
fun PlaylistScreen(
  playlistStore: PlaylistStore,
  player: SoundPlaying,
  onOpenSettings: () -> Unit,
  modifier: Modifier = Modifier,
  onExploreDeepSound: (() -> Unit)? = null,
) {
  val state by playlistStore.state.collectAsStateWithLifecycle()
  val playback by player.playback.collectAsStateWithLifecycle()
  val scope = rememberCoroutineScope()
  val bottomInset = Dp.rhythm + LocalMiniPlayerClearance.current

  // iOS's `.task { await store.refreshIfNeeded() }`. A refresh that fails over
  // a cached playlist leaves it on screen; only a first load lands on Failed.
  LaunchedEffect(playlistStore) { playlistStore.load() }

  Box(modifier.fillMaxSize()) {
    AtmosphereBackground()

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
      PlaylistHeader(onOpenSettings)

      AnimatedContent(
        targetState = state,
        // Only a change of *kind* crossfades; a save or removal inside a loaded
        // list is the rows' own `animateItem` to show.
        contentKey = { it.kind },
        transitionSpec = {
          (fadeIn(bloom()) + scaleIn(bloom(), initialScale = BLOOM_FROM_SCALE)) togetherWith fadeOut(exhale())
        },
        label = "playlist-content",
      ) { shown ->
        when (shown) {
          PlaylistState.Loading -> Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            PlaylistSkeleton(Modifier.padding(top = Dp.rhythm, bottom = bottomInset))
          }

          is PlaylistState.Failed -> Failure(onRetry = { scope.launch { playlistStore.load() } })

          is PlaylistState.Loaded -> if (shown.entries.isEmpty()) {
            Invitation(onExploreDeepSound)
          } else {
            SavedSounds(
              entries = shown.entries,
              playback = playback,
              bottomInset = bottomInset,
              onPlay = { index -> player.play(shown.entries, index) },
              onRemove = { entry -> scope.launch { playlistStore.toggle(entry.track, entry.collection) } },
            )
          }
        }
      }
    }
  }
}

/** The four things the content can be, for [AnimatedContent]'s key. */
private val PlaylistState.kind: Int
  get() = when (this) {
    PlaylistState.Loading -> 0
    is PlaylistState.Failed -> 1
    is PlaylistState.Loaded -> if (entries.isEmpty()) 2 else 3
  }

// MARK: - Header

/**
 * The pinned header — week 2's You header, retitled for the playlist: the
 * wordmark, its caption, and the frosted Settings control trailing.
 */
@Composable
private fun PlaylistHeader(onOpenSettings: () -> Unit) {
  Row(
    Modifier
      .fillMaxWidth()
      .padding(horizontal = Dp.edge)
      .padding(top = HEADER_PADDING_TOP, bottom = HEADER_PADDING_BOTTOM),
    horizontalArrangement = Arrangement.spacedBy(HEADER_SPACING),
    verticalAlignment = Alignment.Top,
  ) {
    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(HEADER_TITLE_SPACING)) {
      Text(stringResource(R.string.playlist_title), style = DeepType.wordmark, color = Color.deepPlum)
      Text(
        text = stringResource(R.string.playlist_subtitle),
        style = DeepType.caption,
        color = Color.driftGrey,
        maxLines = 1,
      )
    }
    HeaderIconButton(
      icon = ProfileIcons.Sliders,
      contentDescription = stringResource(R.string.playlist_settings),
      onClick = onOpenSettings,
    )
  }
}

// MARK: - Content

@Composable
private fun SavedSounds(
  entries: List<SoundQueueEntry>,
  playback: SoundPlayback,
  bottomInset: Dp,
  onPlay: (Int) -> Unit,
  onRemove: (SoundQueueEntry) -> Unit,
) {
  LazyColumn(
    Modifier.fillMaxSize(),
    contentPadding = PaddingValues(start = Dp.edge, end = Dp.edge, top = Dp.rhythm, bottom = bottomInset),
    verticalArrangement = Arrangement.spacedBy(ROW_GAP),
  ) {
    item(key = "actions") {
      Row(
        Modifier.padding(bottom = Dp.rhythm - ROW_GAP),
        horizontalArrangement = Arrangement.spacedBy(ACTIONS_SPACING),
      ) {
        SoundActionButton(
          title = stringResource(R.string.deepsound_play),
          icon = PlayerIcons.Play,
          onClick = { onPlay(0) },
          modifier = Modifier.weight(1f),
        )
        SoundActionButton(
          title = stringResource(R.string.deepsound_shuffle),
          icon = SoundIcons.Shuffle,
          // A random place to begin; the queue itself stays in saved order, as on iOS.
          onClick = { onPlay(Random.nextInt(entries.size)) },
          modifier = Modifier.weight(1f),
        )
      }
    }

    itemsIndexed(entries, key = { _, entry -> entry.track.id }) { index, entry ->
      PlaylistTrackRow(
        entry = entry,
        isCurrent = playback.isCurrent(entry.track, entry.collection),
        onPlay = { onPlay(index) },
        onRemove = { onRemove(entry) },
        modifier = Modifier.animateItem(),
      )
    }
  }
}

/**
 * Genuine emptiness reads as an invitation, not a fault — and never as a
 * dimmed button.
 *
 * No panel around the words: a full-width frosted pill carries the weight of
 * *content* on the one screen whose whole message is that there is none. The
 * lines sit bare on the atmosphere, and the only surface left is the way out —
 * the frosted chip the failure note also wears, hugging its text.
 */
@Composable
private fun Invitation(onExploreDeepSound: (() -> Unit)?) {
  Column(
    Modifier
      .fillMaxSize()
      .verticalScroll(rememberScrollState())
      .padding(horizontal = Dp.edge)
      .padding(top = Dp.rhythm + INVITATION_TOP_AIR),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(INVITATION_SPACING),
  ) {
    Column(
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(INVITATION_TEXT_SPACING),
    ) {
      Text(stringResource(R.string.playlist_empty_title), style = DeepType.sectionTitle, color = Color.deepPlum)
      Text(
        text = stringResource(R.string.playlist_empty_body),
        style = DeepType.caption,
        color = Color.driftGrey,
        textAlign = TextAlign.Center,
        modifier = Modifier.widthIn(max = INVITATION_BODY_MAX_WIDTH),
      )
    }
    if (onExploreDeepSound != null) {
      FrostedChipButton(stringResource(R.string.playlist_explore), onExploreDeepSound)
    }
  }
}

@Composable
private fun Failure(onRetry: () -> Unit) {
  Column(
    Modifier
      .fillMaxSize()
      .verticalScroll(rememberScrollState())
      .padding(horizontal = Dp.edge)
      .padding(top = Dp.rhythm)
      .padding(vertical = FAILURE_PADDING_VERTICAL),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(FAILURE_SPACING),
  ) {
    Text(
      text = stringResource(R.string.playlist_failed),
      style = DeepType.body,
      color = Color.driftGrey,
      textAlign = TextAlign.Center,
    )
    FrostedChipButton(stringResource(R.string.playlist_try_again), onRetry)
  }
}

/** The frosted chip that hugs its label — iOS's `.frostedCard(cornerRadius: .chip)` button. */
@Composable
private fun FrostedChipButton(title: String, onClick: () -> Unit) {
  Text(
    text = title,
    style = DeepType.bodyMedium,
    color = Color.deepPlum,
    modifier = Modifier
      .softPress()
      .frostedCard(cornerRadius = Dp.chip)
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        role = Role.Button,
        onClick = onClick,
      )
      .padding(horizontal = CHIP_PADDING_HORIZONTAL, vertical = CHIP_PADDING_VERTICAL),
  )
}

// MARK: - Previews

@Preview(showBackground = true, name = "Playlist — saved sounds")
@Composable
private fun PlaylistSavedPreview() {
  DeepTheme {
    PlaylistScreen(
      playlistStore = remember { MockPlaylistStore.sample },
      player = remember { MockSoundPlayer.idle() },
      onOpenSettings = {},
    )
  }
}

@Preview(showBackground = true, name = "Playlist — one playing")
@Composable
private fun PlaylistPlayingPreview() {
  DeepTheme {
    PlaylistScreen(
      playlistStore = remember { MockPlaylistStore.sample },
      player = remember { MockSoundPlayer(entries = PlaylistFixtures.saved, index = 1, isPlaying = true) },
      onOpenSettings = {},
    )
  }
}

@Preview(showBackground = true, name = "Playlist — nothing saved")
@Composable
private fun PlaylistEmptyPreview() {
  DeepTheme {
    PlaylistScreen(
      playlistStore = remember { MockPlaylistStore.empty },
      player = remember { MockSoundPlayer.idle() },
      onOpenSettings = {},
      onExploreDeepSound = {},
    )
  }
}

@Preview(showBackground = true, name = "Playlist — loading")
@Composable
private fun PlaylistLoadingPreview() {
  DeepTheme {
    PlaylistScreen(
      playlistStore = remember { MockPlaylistStore.loading },
      player = remember { MockSoundPlayer.idle() },
      onOpenSettings = {},
    )
  }
}

@Preview(showBackground = true, name = "Playlist — unreachable")
@Composable
private fun PlaylistFailedPreview() {
  DeepTheme {
    PlaylistScreen(
      playlistStore = remember { MockPlaylistStore.failed },
      player = remember { MockSoundPlayer.idle() },
      onOpenSettings = {},
    )
  }
}
