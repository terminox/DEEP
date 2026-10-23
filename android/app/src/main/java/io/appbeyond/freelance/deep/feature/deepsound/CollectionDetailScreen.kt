package io.appbeyond.freelance.deep.feature.deepsound

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.components.SoundActionButton
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTime
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTrack
import io.appbeyond.freelance.deep.feature.deepsound.player.MockSoundPlayer
import io.appbeyond.freelance.deep.feature.deepsound.player.SoundPlaying
import io.appbeyond.freelance.deep.feature.deepsound.player.play
import io.appbeyond.freelance.deep.feature.playlist.store.MockPlaylistStore
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistStore
import io.appbeyond.freelance.deep.feature.profile.HeaderIconButton
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softPress
import kotlinx.coroutines.launch
import kotlin.random.Random

// MARK: - Constants

/** The header artwork — iOS's 220pt square at `cornerRadius: 24` (the card radius). */
private val ARTWORK_SIZE = 220.dp

/** The artwork's lift — iOS's `shadow(lavenderMist 0.35, radius: 28, y: 16)`. */
private const val ARTWORK_SHADOW_ALPHA = 0.35f
private val ARTWORK_SHADOW_RADIUS = 28.dp
private val ARTWORK_SHADOW_OFFSET_Y = 16.dp

private val HEADER_SPACING = 16.dp
private val TITLE_BLOCK_SPACING = 4.dp
private val META_TOP_PADDING = 2.dp
private val ACTIONS_SPACING = 12.dp

/** The bar's height below the status bar, and its title's clearance of the chevron. */
private val TOP_BAR_PADDING_VERTICAL = 6.dp
private val TOP_BAR_TITLE_INSET = 56.dp

/** iOS's `.padding(.top, 12)` on the scroll content. */
private val CONTENT_TOP_PADDING = 12.dp

private val ROW_SPACING = 16.dp
private val ROW_PADDING_VERTICAL = 14.dp

/** The track number's column — iOS's `.frame(width: 24)`. */
private val NUMBER_WIDTH = 24.dp

/**
 * The saved/remove menu — Android's `DropdownMenu` has no iOS counterpart to cite;
 * `.contextMenu` there is the system's own chrome, with no corner radius of its own.
 */
private val MENU_RADIUS = 16.dp

/** Fixed-width digits, so a column of numbers and durations lines up. */
private const val TABULAR_FIGURES = "tnum"

// MARK: - Screen

/**
 * The album-style detail page: a large header with artwork, title, metadata,
 * Play / Shuffle, then the track list.
 *
 * Ported from Deep/Deep/Features/DeepSound/Components/CollectionDetailView.swift.
 * iOS rides a system navigation bar with an inline title; this is pushed onto
 * the tab's own stack, which has no bar, so the screen draws its own — a
 * frosted back chevron and the collection's title, over the atmosphere with no
 * bar background, as iOS hides the toolbar background. Predictive back is the
 * shell's `BackHandler`; [onBack] is only the chevron.
 *
 * **No premium lock — a deliberate divergence.** iOS gates premium tracks
 * behind a "A premium sound" alert until the member subscribes. Android plays
 * everything for now: there is no subscription store on this side yet, and a
 * lock with no way through it would only be a dead end.
 *
 * @param collection the collection to show; its tracks play as one queue.
 * @param player the shared player — the same one the shell's mini player reads.
 * @param playlistStore where a long-pressed track is saved or removed.
 * @param onBack pops the screen.
 */
@Composable
fun CollectionDetailScreen(
  collection: SoundCollection,
  player: SoundPlaying,
  playlistStore: PlaylistStore,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val playback by player.playback.collectAsStateWithLifecycle()
  val playlist by playlistStore.state.collectAsStateWithLifecycle()
  val scope = rememberCoroutineScope()

  // Keyed on the store's state so every save or removal re-reads the marks.
  val savedIds = remember(playlist, collection) {
    collection.tracks.filter { playlistStore.isSaved(it.id) }.map { it.id }.toSet()
  }
  val bottomInset = Dp.rhythm + LocalMiniPlayerClearance.current

  Box(
    modifier
      .fillMaxSize()
      .background(Color.moonCream),
  ) {
    AtmosphereBackground()

    Column(
      Modifier
        .fillMaxSize()
        .statusBarsPadding(),
    ) {
      DetailTopBar(title = collection.title, onBack = onBack)

      LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = CONTENT_TOP_PADDING, bottom = bottomInset),
      ) {
        item(key = "header") { ArtworkHeader(collection) }

        item(key = "actions") {
          Row(
            Modifier
              .padding(top = Dp.rhythm)
              .padding(horizontal = Dp.edge),
            horizontalArrangement = Arrangement.spacedBy(ACTIONS_SPACING),
          ) {
            SoundActionButton(
              title = stringResource(R.string.deepsound_play),
              icon = SoundIcons.Play,
              onClick = { if (collection.tracks.isNotEmpty()) player.play(collection, startIndex = 0) },
              modifier = Modifier.weight(1f),
            )
            SoundActionButton(
              title = stringResource(R.string.deepsound_shuffle),
              icon = SoundIcons.Shuffle,
              // A random place to begin; the queue itself stays in order, as on iOS.
              onClick = {
                if (collection.tracks.isNotEmpty()) {
                  player.play(collection, startIndex = Random.nextInt(collection.trackCount))
                }
              },
              modifier = Modifier.weight(1f),
            )
          }
        }

        item(key = "tracks-gap") { Spacer(Modifier.height(Dp.rhythm)) }

        itemsIndexed(collection.tracks, key = { _, track -> track.id }) { index, track ->
          TrackRow(
            number = index + 1,
            track = track,
            isCurrent = playback.isCurrent(track, collection),
            isSaved = track.id in savedIds,
            onPlay = { player.play(collection.queue(), index) },
            onToggleSaved = { scope.launch { playlistStore.toggle(track, collection) } },
            modifier = Modifier.padding(horizontal = Dp.edge),
          )
        }
      }
    }
  }
}

// MARK: - Top bar

/**
 * The back chevron at the leading edge and the collection's title centred over
 * the whole width — iOS's inline navigation bar, with no bar background.
 */
@Composable
private fun DetailTopBar(title: String, onBack: () -> Unit) {
  Box(
    Modifier
      .fillMaxWidth()
      .padding(horizontal = Dp.edge, vertical = TOP_BAR_PADDING_VERTICAL),
    contentAlignment = Alignment.Center,
  ) {
    HeaderIconButton(
      icon = SoundIcons.ChevronBack,
      contentDescription = stringResource(R.string.deepsound_back),
      onClick = onBack,
      modifier = Modifier.align(Alignment.CenterStart),
    )
    Text(
      text = title,
      style = DeepType.sectionTitle,
      color = Color.deepPlum,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
      textAlign = TextAlign.Center,
      modifier = Modifier.padding(horizontal = TOP_BAR_TITLE_INSET),
    )
  }
}

// MARK: - Header

@Composable
private fun ArtworkHeader(collection: SoundCollection) {
  val shape = RoundedCornerShape(Dp.card)
  val tracks = pluralStringResource(
    R.plurals.deepsound_track_count,
    collection.trackCount,
    collection.trackCount,
  )
  val minutes = stringResource(
    R.string.deepsound_minutes,
    SoundTime.minutes(collection.totalDurationSeconds.toDouble()),
  )

  Column(
    Modifier
      .fillMaxWidth()
      .padding(horizontal = Dp.edge),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(HEADER_SPACING),
  ) {
    ArtworkImage(
      url = collection.imageUrl,
      palette = collection.palette,
      contentDescription = null,
      modifier = Modifier
        .size(ARTWORK_SIZE)
        .dropShadow(
          shape = shape,
          shadow = Shadow(
            radius = ARTWORK_SHADOW_RADIUS,
            color = Color.lavenderMist.copy(alpha = ARTWORK_SHADOW_ALPHA),
            offset = DpOffset(0.dp, ARTWORK_SHADOW_OFFSET_Y),
          ),
        )
        .clip(shape),
    )

    Column(
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(TITLE_BLOCK_SPACING),
    ) {
      Text(
        collection.title,
        style = DeepType.displayTitle,
        color = Color.deepPlum,
        textAlign = TextAlign.Center,
      )
      Text(
        collection.subtitle,
        style = DeepType.body,
        color = Color.driftGrey,
        textAlign = TextAlign.Center,
      )
      Text(
        stringResource(R.string.deepsound_collection_meta, tracks, minutes),
        style = DeepType.caption,
        color = Color.driftGrey,
        textAlign = TextAlign.Center,
        modifier = Modifier.padding(top = META_TOP_PADDING),
      )
    }
  }
}

// MARK: - Track row

/**
 * One track: its number, title and length. Tapping plays the collection from
 * here; a long press opens the one place a collection offers to save a sound,
 * so the row itself stays as quiet as it was.
 *
 * The current track reads in lavender at medium weight. iOS uses semibold, but
 * the bundled Inter is declared at 400 and 500 only — a 600 request would be
 * synthesised, so medium is the heaviest honest weight here.
 *
 * The title takes `weight(1f)` rather than sitting beside a `Spacer`, so it
 * truncates only when it genuinely runs out of room.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun TrackRow(
  number: Int,
  track: SoundTrack,
  isCurrent: Boolean,
  isSaved: Boolean,
  onPlay: () -> Unit,
  onToggleSaved: () -> Unit,
  modifier: Modifier = Modifier,
) {
  var menuOpen by remember { mutableStateOf(false) }
  val haptics = LocalHapticFeedback.current
  val digits = DeepType.body.copy(fontFeatureSettings = TABULAR_FIGURES)

  Box(modifier) {
    Row(
      Modifier
        .fillMaxWidth()
        .softPress()
        .combinedClickable(
          interactionSource = remember { MutableInteractionSource() },
          indication = null,
          role = Role.Button,
          onClick = onPlay,
          onLongClick = {
            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            menuOpen = true
          },
        )
        .padding(vertical = ROW_PADDING_VERTICAL),
      horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Text(
        text = number.toString(),
        style = digits,
        color = Color.driftGrey,
        textAlign = TextAlign.Center,
        modifier = Modifier.width(NUMBER_WIDTH),
      )
      Text(
        text = track.title,
        style = if (isCurrent) DeepType.bodyMedium else DeepType.body,
        color = if (isCurrent) Color.lavenderMist else Color.deepPlum,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.weight(1f),
      )
      Text(
        text = SoundTime.clock(track.durationSeconds.toDouble()),
        style = DeepType.caption.copy(fontFeatureSettings = TABULAR_FIGURES),
        color = Color.driftGrey,
      )
    }

    DropdownMenu(
      expanded = menuOpen,
      onDismissRequest = { menuOpen = false },
      shape = RoundedCornerShape(MENU_RADIUS),
      containerColor = Color.moonCream,
    ) {
      DropdownMenuItem(
        text = {
          Text(
            stringResource(
              if (isSaved) R.string.deepsound_remove_from_playlist else R.string.deepsound_save_to_playlist,
            ),
            style = DeepType.body,
            color = Color.deepPlum,
          )
        },
        leadingIcon = {
          Icon(
            if (isSaved) SoundIcons.BookmarkSlash else SoundIcons.Bookmark,
            contentDescription = null,
            tint = Color.deepPlum,
          )
        },
        onClick = {
          menuOpen = false
          onToggleSaved()
        },
      )
    }
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Collection detail")
@Composable
private fun CollectionDetailPreview() {
  DeepTheme {
    CollectionDetailScreen(
      collection = SoundFixtures.oceanDepths,
      player = remember { MockSoundPlayer.idle() },
      playlistStore = remember { MockPlaylistStore.empty },
      onBack = {},
    )
  }
}

@Preview(showBackground = true, name = "Collection detail — playing")
@Composable
private fun CollectionDetailPlayingPreview() {
  DeepTheme {
    CollectionDetailScreen(
      collection = SoundFixtures.oceanDepths,
      player = remember { MockSoundPlayer.playing() },
      playlistStore = remember { MockPlaylistStore.sample },
      onBack = {},
    )
  }
}
