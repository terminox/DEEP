package io.appbeyond.freelance.deep.feature.deepsound.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.lerp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.LyricsSheet
import io.appbeyond.freelance.deep.feature.deepsound.PlayerIcons
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueue
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTime
import io.appbeyond.freelance.deep.feature.deepsound.player.MockSoundPlayer
import io.appbeyond.freelance.deep.feature.deepsound.player.SoundPlaying
import io.appbeyond.freelance.deep.feature.deepsound.store.MockSoundLibrary
import io.appbeyond.freelance.deep.feature.deepsound.store.SoundLibrary
import io.appbeyond.freelance.deep.feature.playlist.components.SaveTrackButton
import io.appbeyond.freelance.deep.feature.playlist.store.MockPlaylistStore
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistState
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistStore
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.settle
import io.appbeyond.freelance.deep.theme.softLilac
import io.appbeyond.freelance.deep.theme.softPress
import kotlinx.coroutines.launch

// MARK: - Constants

/** The backdrop's middle and bottom stops — iOS's `.lavenderMist.opacity(0.7)`, `.blushPowder.opacity(0.6)`. */
private const val BACKDROP_MID_ALPHA = 0.7f
private const val BACKDROP_LOW_ALPHA = 0.6f

/**
 * The stand-in for iOS's `.ultraThinMaterial.opacity(0.4)` over the gradient —
 * a pale wash with no blur, since there is nothing behind an opaque screen to
 * blur anyway.
 */
private const val BACKDROP_WASH_ALPHA = 0.16f

/** The grab handle — iOS's 40×5 capsule in plum at 0.22, padded 12 above and 4 below. */
private val HANDLE_WIDTH = 40.dp
private val HANDLE_HEIGHT = 5.dp
private const val HANDLE_ALPHA = 0.22f
private val HANDLE_PADDING_TOP = 12.dp
private val HANDLE_PADDING_BOTTOM = 4.dp

/** Air around the artwork — iOS's `Spacer(minLength: 8)` above, `Spacer(minLength: 24)` below. */
private val ARTWORK_AIR_TOP = 8.dp
private val ARTWORK_AIR_BOTTOM = 24.dp
private val ARTWORK_INSET = 28.dp

/** The artwork's corner radius — iOS's `cornerRadius: 22`. */
private val ARTWORK_RADIUS = 22.dp

/** Paused, the artwork steps back — iOS's `artworkScale`. */
private const val ARTWORK_PAUSED_SCALE = 0.84f

/** The artwork's bloom, playing vs paused — iOS's `.shadow(...)` pair. */
private const val SHADOW_PLAYING_ALPHA = 0.45f
private const val SHADOW_PAUSED_ALPHA = 0.22f
private val SHADOW_PLAYING_RADIUS = 34.dp
private val SHADOW_PAUSED_RADIUS = 16.dp
private val SHADOW_PLAYING_Y = 20.dp
private val SHADOW_PAUSED_Y = 10.dp

/** The controls block — iOS's `VStack(spacing: 26)`, padded 32 across and 40 below. */
private val CONTROLS_SPACING = 26.dp
private val CONTROLS_INSET = 32.dp
private val CONTROLS_BOTTOM = 40.dp

/**
 * The track title — iOS's semibold `.title3` (20pt). Inter's heaviest weight in
 * the bundled family is Medium, so the step up in size carries the emphasis.
 */
private val TRACK_TITLE_STYLE = DeepType.sectionTitle.copy(fontSize = 20.sp, lineHeight = 26.sp)

/** iOS's `VStack(spacing: 3)` under the title. */
private val TITLE_SPACING = 3.dp

/** Clock labels tick, so their digits are fixed-width — iOS's `.monospacedDigit()`. */
private val CLOCK_STYLE = DeepType.caption.copy(fontFeatureSettings = "tnum")

/** The remaining-time label's sign — iOS's `"-\(...)"`. */
private const val REMAINING_PREFIX = "-"

/** Slider-to-clock gap — iOS's `VStack(spacing: 6)`. */
private val SCRUBBER_SPACING = 6.dp

/** Transport — iOS's `HStack(spacing: 44)`, 28pt skips in 56pt frames, a 44pt play in 64. */
private val TRANSPORT_SPACING = 44.dp
private val SKIP_GLYPH = 28.dp
private val SKIP_TARGET = 56.dp
private val PLAY_GLYPH = 44.dp
private val PLAY_TARGET = 64.dp

/** Volume — iOS's `HStack(spacing: 12)` with `.footnote` speakers and a 0.8 lavender fill. */
private val VOLUME_SPACING = 12.dp
private val SPEAKER_GLYPH = 16.dp
private const val VOLUME_FILL_ALPHA = 0.8f

/** The bottom row — iOS's `.padding(.horizontal, 24)` and 44pt utility targets. */
private val BOTTOM_ROW_INSET = 24.dp
private val UTILITY_TARGET = 44.dp
private val UTILITY_GLYPH = 20.dp

/** How far a swipe down must travel to count as all the way closed — the pill's distance, mirrored. */
private val COLLAPSE_DRAG_DISTANCE = 300.dp

// MARK: - Screen

/**
 * The full-screen player. Ported from `Deep/Deep/Features/DeepSound/Components/NowPlayingView.swift`:
 * a large artwork that contracts when paused, a draggable scrubber, transport,
 * volume, and a bottom utility row — Apple Music's Now Playing, retinted to
 * DEEP and with softened motion.
 *
 * Two deliberate departures from iOS. The bottom row carries only Lyrics: the
 * AirPlay button has no honest Android counterpart (the output switcher is a
 * system surface, not the app's), so it is dropped rather than faked. And the
 * volume is the player's own gain ([SoundPlaying.setVolume], starting at 0.6
 * like `AVPlayer.volume` on iOS), not the system volume.
 *
 * A leaf. The morph from the mini pill, the predictive-back shrink and the
 * seekable transition state all belong to the shell; this screen only lays out
 * its contents opaquely, so the morph reads cleanly, and reports a swipe down
 * through [onDragDown] / [onDragDownEnd] so the shell can scrub the collapse.
 * The sliders consume their own drags, so scrubbing never collapses the screen.
 *
 * @param artworkModifier applied first on the artwork, before its sizing —
 *   where the shell attaches `Modifier.sharedElement(...)`.
 * @param onDragDown the swipe's progress, 0…1, over a [COLLAPSE_DRAG_DISTANCE]
 *   travel. Upward travel clamps to 0.
 * @param onDragDownEnd the release velocity in px/s, positive downward (toward
 *   closed). A cancelled drag reports 0.
 */
@Composable
fun NowPlayingScreen(
  player: SoundPlaying,
  playlistStore: PlaylistStore,
  library: SoundLibrary,
  onCollapse: () -> Unit,
  modifier: Modifier = Modifier,
  artworkModifier: Modifier = Modifier,
  onDragDown: (fraction: Float) -> Unit = {},
  onDragDownEnd: (velocity: Float) -> Unit = {},
) {
  val playback by player.playback.collectAsStateWithLifecycle()
  val playlist by playlistStore.state.collectAsStateWithLifecycle()
  val scope = rememberCoroutineScope()
  var showLyrics by rememberSaveable { mutableStateOf(false) }
  val onDown by rememberUpdatedState(onDragDown)
  val onDownEnd by rememberUpdatedState(onDragDownEnd)

  val track = playback.currentTrack
  val collection = playback.collection

  Box(
    modifier
      .fillMaxSize()
      .nowPlayingBackdrop()
      .pointerInput(Unit) {
        val distance = COLLAPSE_DRAG_DISTANCE.toPx()
        val tracker = VelocityTracker()
        var travelled = 0f
        detectVerticalDragGestures(
          onDragStart = {
            travelled = 0f
            tracker.resetTracking()
          },
          onDragEnd = { onDownEnd(tracker.calculateVelocity().y) },
          onDragCancel = { onDownEnd(0f) },
          onVerticalDrag = { change, dragAmount ->
            change.consume()
            travelled += dragAmount
            // The accumulated travel, not the pointer's local position — the
            // shell is shrinking this screen under the finger as it goes.
            tracker.addPosition(change.uptimeMillis, Offset(0f, travelled))
            onDown((travelled / distance).coerceIn(0f, 1f))
          },
        )
      },
  ) {
    Column(Modifier.fillMaxSize().systemBarsPadding()) {
      GrabHandle(onCollapse)

      Box(
        Modifier
          .weight(1f)
          .fillMaxWidth()
          .padding(horizontal = ARTWORK_INSET)
          .padding(top = ARTWORK_AIR_TOP, bottom = ARTWORK_AIR_BOTTOM),
        contentAlignment = Alignment.Center,
      ) {
        NowPlayingArtwork(collection, playback.isPlaying, artworkModifier)
      }

      Column(
        Modifier
          .fillMaxWidth()
          .padding(horizontal = CONTROLS_INSET)
          .padding(bottom = CONTROLS_BOTTOM),
        verticalArrangement = Arrangement.spacedBy(CONTROLS_SPACING),
      ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
          // Greedy rather than a Spacer, so the title takes the room it has.
          Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(TITLE_SPACING)) {
            Text(
              text = track?.title.orEmpty(),
              style = TRACK_TITLE_STYLE,
              color = Color.deepPlum,
              maxLines = 1,
              overflow = TextOverflow.Ellipsis,
            )
            Text(
              text = collection?.title.orEmpty(),
              style = DeepType.body,
              color = Color.driftGrey,
              maxLines = 1,
              overflow = TextOverflow.Ellipsis,
            )
          }
          // Saving the sound to the playlist — the screen's one utility control.
          if (track != null && collection != null) {
            // Keyed on the store's state, so a save anywhere refills the mark here.
            val saved = remember(playlist, track.id) { playlistStore.isSaved(track.id) }
            SaveTrackButton(
              saved = saved,
              onToggle = { scope.launch { playlistStore.toggle(track, collection) } },
            )
          }
        }

        Scrubber(player, playback.duration)

        Row(
          Modifier.fillMaxWidth(),
          horizontalArrangement = Arrangement.spacedBy(TRANSPORT_SPACING, Alignment.CenterHorizontally),
          verticalAlignment = Alignment.CenterVertically,
        ) {
          GlyphButton(
            icon = PlayerIcons.Previous,
            label = stringResource(R.string.player_previous),
            glyphSize = SKIP_GLYPH,
            target = SKIP_TARGET,
            onClick = player::previous,
          )
          GlyphButton(
            icon = if (playback.isPlaying) PlayerIcons.Pause else PlayerIcons.Play,
            label = stringResource(if (playback.isPlaying) R.string.player_pause else R.string.player_play),
            glyphSize = PLAY_GLYPH,
            target = PLAY_TARGET,
            onClick = player::togglePlayPause,
          )
          GlyphButton(
            icon = PlayerIcons.Next,
            label = stringResource(R.string.player_next),
            glyphSize = SKIP_GLYPH,
            target = SKIP_TARGET,
            onClick = player::next,
          )
        }

        Row(
          horizontalArrangement = Arrangement.spacedBy(VOLUME_SPACING),
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Icon(PlayerIcons.Speaker, contentDescription = null, tint = Color.driftGrey, modifier = Modifier.size(SPEAKER_GLYPH))
          val volumeLabel = stringResource(R.string.player_volume)
          SoundSlider(
            value = playback.volume.toFloat(),
            onValueChange = { player.setVolume(it.toDouble()) },
            activeColor = Color.lavenderMist.copy(alpha = VOLUME_FILL_ALPHA),
            modifier = Modifier.weight(1f).semantics { contentDescription = volumeLabel },
          )
          Icon(PlayerIcons.SpeakerWave, contentDescription = null, tint = Color.driftGrey, modifier = Modifier.size(SPEAKER_GLYPH))
        }

        Row(
          Modifier.fillMaxWidth().padding(horizontal = BOTTOM_ROW_INSET),
          horizontalArrangement = Arrangement.End,
        ) {
          // Lyrics — opens the (multi-language) lyrics sheet for the current track.
          GlyphButton(
            icon = PlayerIcons.List,
            label = stringResource(R.string.player_lyrics),
            glyphSize = UTILITY_GLYPH,
            target = UTILITY_TARGET,
            tint = Color.driftGrey,
            onClick = { if (track != null) showLyrics = true },
          )
        }
      }
    }
  }

  if (showLyrics && track != null) {
    LyricsSheet(track = track, library = library, onDismiss = { showLyrics = false })
  }
}

// MARK: - Pieces

/**
 * The opaque base, the gradient, and the material stand-in — iOS's `background`,
 * drawn to the very edges beneath the system bars.
 */
private fun Modifier.nowPlayingBackdrop(): Modifier = drawBehind {
  drawRect(Color.softLilac)
  drawRect(
    Brush.verticalGradient(
      listOf(
        Color.softLilac,
        Color.lavenderMist.copy(alpha = BACKDROP_MID_ALPHA),
        Color.blushPowder.copy(alpha = BACKDROP_LOW_ALPHA),
      ),
    ),
  )
  drawRect(Color.moonCream.copy(alpha = BACKDROP_WASH_ALPHA))
}

/** The grab handle. Tapping it collapses, as it does on iOS. */
@Composable
private fun GrabHandle(onCollapse: () -> Unit) {
  val label = stringResource(R.string.player_close)
  Box(
    Modifier
      .fillMaxWidth()
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        role = Role.Button,
        onClickLabel = label,
        onClick = onCollapse,
      )
      .semantics { contentDescription = label }
      .padding(top = HANDLE_PADDING_TOP, bottom = HANDLE_PADDING_BOTTOM),
    contentAlignment = Alignment.Center,
  ) {
    Box(
      Modifier
        .size(HANDLE_WIDTH, HANDLE_HEIGHT)
        .clip(RoundedCornerShape(HANDLE_HEIGHT))
        .background(Color.deepPlum.copy(alpha = HANDLE_ALPHA)),
    )
  }
}

/**
 * The square artwork. Playing, it stands full size in a deep bloom; paused, it
 * steps back to 0.84 and the bloom tightens — on DEEP's [settle] spring, and
 * not at all under reduced motion, where it simply snaps.
 */
@Composable
private fun NowPlayingArtwork(
  collection: SoundCollection?,
  isPlaying: Boolean,
  artworkModifier: Modifier,
) {
  val reduceMotion = rememberReduceMotion()
  val presence by animateFloatAsState(
    targetValue = if (isPlaying) 1f else 0f,
    animationSpec = if (reduceMotion) snap() else settle(),
    label = "now-playing-artwork",
  )
  // The spring may overshoot a hair; the scale can wear that, the shadow can't.
  val bloom = presence.coerceIn(0f, 1f)
  val shape = RoundedCornerShape(ARTWORK_RADIUS)

  ArtworkImage(
    url = collection?.imageUrl,
    palette = collection?.palette,
    modifier = artworkModifier
      .aspectRatio(1f)
      .graphicsLayer {
        val scale = ARTWORK_PAUSED_SCALE + (1f - ARTWORK_PAUSED_SCALE) * presence
        scaleX = scale
        scaleY = scale
      }
      .dropShadow(
        shape = shape,
        shadow = Shadow(
          radius = lerp(SHADOW_PAUSED_RADIUS, SHADOW_PLAYING_RADIUS, bloom),
          color = Color.lavenderMist.copy(
            alpha = SHADOW_PAUSED_ALPHA + (SHADOW_PLAYING_ALPHA - SHADOW_PAUSED_ALPHA) * bloom,
          ),
          offset = DpOffset(0.dp, lerp(SHADOW_PAUSED_Y, SHADOW_PLAYING_Y, bloom)),
        ),
      )
      .clip(shape),
  )
}

/**
 * The scrubber and its two clocks. Its own composable so the elapsed tick
 * recomposes this and nothing else on the screen.
 *
 * Holds a local position while the finger is down, so the ticking clock never
 * fights the drag, and seeks only on release — iOS's `isScrubbing` /
 * `scrubValue` pair folded into one nullable.
 */
@Composable
private fun Scrubber(player: SoundPlaying, duration: Double) {
  val elapsed by player.elapsed.collectAsStateWithLifecycle()
  var scrub by remember { mutableStateOf<Float?>(null) }
  val progress = scrub ?: SoundQueue.progress(elapsed, duration).toFloat()
  val shownElapsed = scrub?.let { it * duration } ?: elapsed
  val label = stringResource(R.string.player_position)

  Column(verticalArrangement = Arrangement.spacedBy(SCRUBBER_SPACING)) {
    SoundSlider(
      value = progress,
      onValueChange = { scrub = it },
      onValueChangeFinished = {
        scrub?.let { player.seek(it.toDouble()) }
        scrub = null
      },
      modifier = Modifier.semantics { contentDescription = label },
    )
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      Text(SoundTime.clock(shownElapsed), style = CLOCK_STYLE, color = Color.driftGrey)
      Text(
        REMAINING_PREFIX + SoundTime.clock(maxOf(0.0, duration - shownElapsed)),
        style = CLOCK_STYLE,
        color = Color.driftGrey,
      )
    }
  }
}

/** A bare glyph in a generous target that presses into foam — iOS's `.softPress` transport and utility buttons. */
@Composable
private fun GlyphButton(
  icon: ImageVector,
  label: String,
  glyphSize: Dp,
  target: Dp,
  onClick: () -> Unit,
  tint: Color = Color.deepPlum,
) {
  Box(
    Modifier
      .size(target)
      .softPress()
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        role = Role.Button,
        onClick = onClick,
      ),
    contentAlignment = Alignment.Center,
  ) {
    Icon(icon, contentDescription = label, tint = tint, modifier = Modifier.size(glyphSize))
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Now Playing — playing")
@Composable
private fun NowPlayingPlayingPreview() {
  DeepTheme {
    NowPlayingScreen(
      player = remember { MockSoundPlayer.playing() },
      playlistStore = remember { MockPlaylistStore.empty },
      library = remember { MockSoundLibrary.loaded },
      onCollapse = {},
    )
  }
}

@Preview(showBackground = true, name = "Now Playing — paused")
@Composable
private fun NowPlayingPausedPreview() {
  DeepTheme {
    NowPlayingScreen(
      player = remember { MockSoundPlayer.playing().apply { togglePlayPause() } },
      playlistStore = remember { MockPlaylistStore.empty },
      library = remember { MockSoundLibrary.loaded },
      onCollapse = {},
    )
  }
}

@Preview(showBackground = true, name = "Now Playing — saved")
@Composable
private fun NowPlayingSavedPreview() {
  val player = remember { MockSoundPlayer.playing() }
  val store = remember {
    MockPlaylistStore(PlaylistState.Loaded(listOfNotNull(player.playback.value.currentEntry)))
  }
  DeepTheme {
    NowPlayingScreen(
      player = player,
      playlistStore = store,
      library = remember { MockSoundLibrary.loaded },
      onCollapse = {},
    )
  }
}

@Preview(showBackground = true, name = "Now Playing — idle")
@Composable
private fun NowPlayingIdlePreview() {
  DeepTheme {
    NowPlayingScreen(
      player = remember { MockSoundPlayer.idle() },
      playlistStore = remember { MockPlaylistStore.empty },
      library = remember { MockSoundLibrary.loaded },
      onCollapse = {},
    )
  }
}
