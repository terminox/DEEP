package io.appbeyond.freelance.deep.feature.deepsound.components

import android.os.Build
import androidx.compose.animation.Crossfade
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.LyricsSheet
import io.appbeyond.freelance.deep.feature.deepsound.PlayerIcons
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.feature.deepsound.model.RepeatMode
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundPlayback
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueue
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTime
import io.appbeyond.freelance.deep.feature.deepsound.player.MockSoundPlayer
import io.appbeyond.freelance.deep.feature.deepsound.player.SoundPlaying
import io.appbeyond.freelance.deep.feature.deepsound.player.cycleRepeatMode
import io.appbeyond.freelance.deep.feature.deepsound.player.toggleShuffled
import io.appbeyond.freelance.deep.feature.deepsound.store.MockSoundLibrary
import io.appbeyond.freelance.deep.feature.deepsound.store.SoundLibrary
import io.appbeyond.freelance.deep.feature.playlist.components.SaveTrackButton
import io.appbeyond.freelance.deep.feature.playlist.store.MockPlaylistStore
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistState
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistStore
import io.appbeyond.freelance.deep.feature.rewards.store.ListenReporting
import io.appbeyond.freelance.deep.feature.rewards.store.MockListenReporter
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.shared.components.HeartBurst
import io.appbeyond.freelance.deep.shared.components.LightStatusBarIcons
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.drift
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.settle
import io.appbeyond.freelance.deep.theme.softPress
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

// MARK: - Constants

/** The close button — iOS's 40pt frosted chip, 4 below the status bar. */
private val CLOSE_SIZE = 40.dp
private val CLOSE_GLYPH = 22.dp
private val CLOSE_TOP = 4.dp

/** The photograph's slow breath — iOS's `scaleEffect(drifted ? 1.08 : 1.02)`. */
private const val ARTWORK_REST_SCALE = 1.02f
private const val ARTWORK_DRIFT_SCALE = 1.08f

/** Paused, a soft plum dim falls over the photograph — iOS's `deepPlum.opacity(0.2)`. */
private const val PAUSED_DIM_ALPHA = 0.2f

/** The plum washes that seat cream text on any photo — iOS's `scrim(from:peak:)` pair. */
private const val TOP_SCRIM_PEAK = 0.36f
private val TOP_SCRIM_HEIGHT = 180.dp
private const val BOTTOM_SCRIM_PEAK = 0.4f
private val BOTTOM_SCRIM_HEIGHT = 520.dp

/**
 * Below API 31 there is no blur to soften the photograph behind the controls,
 * so the bottom wash deepens a little to carry the text on its own.
 */
private const val BOTTOM_SCRIM_PEAK_UNBLURRED = 0.55f

/** Each scrim's middle stop as a share of its peak — iOS's `ink.opacity(0.8)` at 0.5. */
private const val SCRIM_MID_SHARE = 0.8f
private const val SCRIM_MID_STOP = 0.5f

/**
 * The progressive blur behind the controls — iOS's `VariableBlurView(maxBlurRadius: 24)`,
 * clear at its top edge, which rests 28 above the controls.
 */
private val BLUR_RADIUS = 24.dp
private val BLUR_LEAD = 28.dp

/** The controls column — iOS's `VStack(spacing: 18)`, 12 above the bottom inset. */
private val CONTROLS_SPACING = 18.dp
private val CONTROLS_BOTTOM = 12.dp

/** The title column and the trailing buttons beside it — iOS's `spacing: 4` both ways. */
private val TITLE_SPACING = 4.dp

/** Cream's softer inks — secondary text and the volume's quiet fill, then a mode switched off. */
private const val SECONDARY_ALPHA = 0.72f
private const val VOLUME_FILL_ALPHA = 0.8f
private const val MODE_OFF_ALPHA = 0.5f

/** The collection line — iOS's `DeepType.micro` with `.tracking(1.6)`. */
private val COLLECTION_STYLE = DeepType.micro.copy(letterSpacing = 1.6.sp)

/** The track title — iOS's semibold `.title2` (22pt). */
private val TRACK_TITLE_STYLE = DeepType.sectionTitle.copy(
  fontSize = 22.sp,
  lineHeight = 28.sp,
  fontWeight = FontWeight.SemiBold,
)

/** Clock labels tick, so their digits are fixed-width — iOS's `.monospacedDigit()`. */
private val CLOCK_STYLE = DeepType.caption.copy(fontFeatureSettings = "tnum")

/** The remaining-time label's sign — iOS's `"-\(...)"`. */
private const val REMAINING_PREFIX = "-"

/** Slider-to-clock gap — iOS's `VStack(spacing: 4)`. */
private val SCRUBBER_SPACING = 4.dp

/** Both sliders' resting track — iOS's `trackHeight: 4`. */
private val SLIDER_TRACK = 4.dp

/** Transport — 24pt skips in 52pt targets, a 68pt cream play with a 24pt glyph, 12 either side of it. */
private val SKIP_GLYPH = 24.dp
private val SKIP_TARGET = 52.dp
private val PLAY_SIZE = 68.dp
private val PLAY_GLYPH = 24.dp
private val PLAY_AIR = 12.dp

/** Shuffle, Repeat and Lyrics — iOS's 18pt glyphs in 44pt targets. */
private val MODE_GLYPH = 18.dp
private val MODE_TARGET = 44.dp

/** Volume — iOS's `HStack(spacing: 12)` with `.footnote` speakers. */
private val VOLUME_SPACING = 12.dp
private val SPEAKER_GLYPH = 16.dp

/** How far a swipe down must travel to count as all the way closed — the pill's distance, mirrored. */
private val COLLAPSE_DRAG_DISTANCE = 300.dp

// MARK: - Screen

/**
 * The full-screen player. Ported from `Deep/Deep/Features/DeepSound/Components/NowPlayingView.swift`:
 * the collection's photograph fills the whole screen, edge to edge under the
 * status bar, and the player sits over its lower part — collection, track,
 * scrubber, transport and volume, seated on a plum scrim and a progressive
 * blur so the photo melts out of focus behind the controls. Shuffle and Repeat
 * flank the transport, as in Spotify; Lyrics and Save sit with the title.
 *
 * While a sound plays the photograph drifts slowly ([drift]); paused it
 * settles back and dims, and under reduced motion it never drifts at all. The
 * status bar's icons turn light for as long as this screen is up, as iOS's
 * `LightStatusBarHostingController` does.
 *
 * Departures from iOS:
 * - **The blur** is a uniform 24dp blur of the photograph, faded in from clear
 *   by a gradient, where iOS's `VariableBlurView` ramps the radius itself. It
 *   needs API 31 (`RenderEffect`); below that `Modifier.blur` is a no-op, so
 *   the bottom scrim deepens a little instead.
 * - **The volume** is the player's own gain ([SoundPlaying.setVolume], starting
 *   at 0.6 like `AVPlayer.volume` on iOS), not the system volume.
 *
 * When a finished track's heart lands, the subtitle gives way for a few
 * seconds to [listenReporter]'s notice in cream — the mini player's swap, at
 * this screen's size, with the full sentence for today's hearts — and an
 * earned heart blooms out of the titles ([HeartBurst]) and is felt once
 * across both surfaces.
 *
 * A leaf. The morph from the mini pill, the predictive-back shrink and the
 * seekable transition state all belong to the shell; this screen only lays out
 * its contents opaquely, so the morph reads cleanly, and reports a swipe down
 * through [onDragDown] / [onDragDownEnd] so the shell can scrub the collapse.
 * The sliders consume their own drags, so scrubbing never collapses the screen.
 *
 * @param onCollapse the close button.
 * @param onDragDown the swipe's progress, 0…1, over a [COLLAPSE_DRAG_DISTANCE]
 *   travel. Upward travel clamps to 0.
 * @param onDragDownEnd the release velocity in px/s, positive downward (toward
 *   closed). A cancelled drag reports 0.
 */
@Composable
fun NowPlayingScreen(
  player: SoundPlaying,
  listenReporter: ListenReporting,
  playlistStore: PlaylistStore,
  library: SoundLibrary,
  onCollapse: () -> Unit,
  modifier: Modifier = Modifier,
  onDragDown: (fraction: Float) -> Unit = {},
  onDragDownEnd: (velocity: Float) -> Unit = {},
) {
  val playback by player.playback.collectAsStateWithLifecycle()
  var showLyrics by rememberSaveable { mutableStateOf(false) }
  val onDown by rememberUpdatedState(onDragDown)
  val onDownEnd by rememberUpdatedState(onDragDownEnd)
  val track = playback.currentTrack
  val blurs = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

  LightStatusBarIcons()

  // The controls' top in this screen's own pixels, for the blur's clear edge.
  // Read only in layout, so a move relays out the blur and recomposes nothing.
  // Measured against the screen itself rather than the root, so a transform
  // the shell lays on the whole screen moves both ends alike.
  val screen = remember { Anchor() }
  var controlsTop by remember { mutableFloatStateOf(Float.NaN) }

  Box(
    modifier
      .fillMaxSize()
      .background(Color.deepPlum)
      .onPlaced { screen.coordinates = it }
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
    val scale = rememberArtworkScale(playback.isPlaying)
    val dim by animateFloatAsState(
      targetValue = if (playback.isPlaying) 0f else PAUSED_DIM_ALPHA,
      animationSpec = settle(),
      label = "now-playing-dim",
    )
    // Decoded for the screen, not for the pill this screen grows out of.
    val decodeSize = LocalWindowInfo.current.containerSize
    val backdrop: @Composable (Modifier) -> Unit = { backdropModifier ->
      Backdrop(
        collection = playback.collection,
        scale = { scale.value },
        dim = { dim.coerceIn(0f, PAUSED_DIM_ALPHA) },
        decodeSize = decodeSize,
        modifier = backdropModifier,
      )
    }

    backdrop(Modifier.fillMaxSize())

    if (blurs) {
      ControlsBlur(clearEdge = { controlsTop }, backdrop = backdrop)
    }

    Scrims(bottomPeak = if (blurs) BOTTOM_SCRIM_PEAK else BOTTOM_SCRIM_PEAK_UNBLURRED)

    Column(
      Modifier
        .fillMaxSize()
        .systemBarsPadding()
        .padding(horizontal = Dp.edge),
    ) {
      CloseButton(onClick = onCollapse, modifier = Modifier.padding(top = CLOSE_TOP))
      Spacer(Modifier.weight(1f))
      Controls(
        player = player,
        playback = playback,
        listenReporter = listenReporter,
        playlistStore = playlistStore,
        onShowLyrics = { if (track != null) showLyrics = true },
        // Globally positioned, not placed: that runs once the whole pass is
        // laid out, so the screen's own coordinates are already in hand.
        modifier = Modifier.onGloballyPositioned { controls ->
          val parent = screen.coordinates?.takeIf { it.isAttached }
          controlsTop = parent?.localPositionOf(controls, Offset.Zero)?.y ?: Float.NaN
        },
      )
    }
  }

  if (showLyrics && track != null) {
    LyricsSheet(track = track, library = library, onDismiss = { showLyrics = false })
  }
}

// MARK: - Photograph

/**
 * The photograph's scale: drifting between 1.02 and 1.08 while a sound plays
 * ([drift]), settling back to 1.02 when it stops ([settle]) — replacing the
 * endless drift with a finite settle is what ends it. Under reduced motion it
 * rests at 1.02.
 */
@Composable
private fun rememberArtworkScale(isPlaying: Boolean): Animatable<Float, AnimationVector1D> {
  val reduceMotion = rememberReduceMotion()
  val scale = remember { Animatable(ARTWORK_REST_SCALE) }
  val drifts = isPlaying && !reduceMotion
  LaunchedEffect(drifts) {
    if (drifts) {
      scale.animateTo(ARTWORK_DRIFT_SCALE, drift())
    } else {
      scale.animateTo(ARTWORK_REST_SCALE, settle())
    }
  }
  return scale
}

/**
 * The photograph on its opaque plum base, so nothing underneath bleeds through
 * while it loads, under a dim that falls when the sound pauses. [scale] and
 * [dim] are read only while drawing, so neither recomposes anything.
 */
@Composable
private fun Backdrop(
  collection: SoundCollection?,
  scale: () -> Float,
  dim: () -> Float,
  decodeSize: IntSize,
  modifier: Modifier = Modifier,
) {
  Box(
    modifier
      .background(Color.deepPlum)
      .clipToBounds()
      .drawWithContent {
        drawContent()
        drawRect(Color.deepPlum.copy(alpha = dim()))
      },
  ) {
    ArtworkImage(
      url = collection?.imageUrl,
      palette = collection?.palette,
      decodeSize = decodeSize,
      modifier = Modifier
        .fillMaxSize()
        .graphicsLayer {
          val shown = scale()
          scaleX = shown
          scaleY = shown
        },
    )
  }
}

/**
 * The photograph again, blurred and faded in from clear — iOS's progressive
 * `VariableBlurView` behind the controls. It runs edge to edge from [clearEdge]
 * (the controls' top, in this screen's pixels) less [BLUR_LEAD] down to the
 * very bottom, under the navigation bar; only that band is blurred, so the
 * drift redraws a band rather than the whole screen.
 *
 * The band holds a full-screen copy of [backdrop] shifted up to line up with
 * the one beneath it. The blur is a uniform [BLUR_RADIUS] faded in by a
 * gradient mask (`DstIn` on an offscreen layer); applied before the mask, so
 * the clear top edge is the mask's, not a blur of the band's own edge.
 */
@Composable
private fun ControlsBlur(
  clearEdge: () -> Float,
  backdrop: @Composable (Modifier) -> Unit,
) {
  val band = remember { Band() }
  Box(
    Modifier
      .fillMaxSize()
      .layout { measurable, constraints ->
        val edge = clearEdge()
        // Until the controls have been placed there is no band to blur.
        band.top = if (edge.isNaN()) {
          constraints.maxHeight
        } else {
          (edge - BLUR_LEAD.toPx()).roundToInt().coerceIn(0, constraints.maxHeight)
        }
        val placeable = measurable.measure(Constraints.fixed(constraints.maxWidth, constraints.maxHeight - band.top))
        layout(constraints.maxWidth, constraints.maxHeight) { placeable.place(0, band.top) }
      }
      .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
      .drawWithContent {
        drawContent()
        drawRect(
          brush = Brush.verticalGradient(listOf(Color.Transparent, Color.Black)),
          blendMode = BlendMode.DstIn,
        )
      }
      .graphicsLayer {
        val radius = BLUR_RADIUS.toPx()
        renderEffect = BlurEffect(radius, radius, TileMode.Clamp)
        clip = true
      },
  ) {
    backdrop(
      Modifier.layout { measurable, constraints ->
        // The band's height plus what sits above it is the screen's. Measured
        // inside the band's own measure, so its top is already this pass's.
        val screen = measurable.measure(Constraints.fixed(constraints.maxWidth, constraints.maxHeight + band.top))
        layout(constraints.maxWidth, constraints.maxHeight) { screen.place(0, -band.top) }
      },
    )
  }
}

/** Where [ControlsBlur]'s band begins, handed from its measure to the copy inside it. */
private class Band {
  var top: Int = 0
}

/** The screen's own layout coordinates, kept for measuring the controls against. */
private class Anchor {
  var coordinates: LayoutCoordinates? = null
}

/**
 * The plum washes that seat moonlit text on any photo: one fading down from
 * the top, one fading up from the bottom — iOS's `scrim(from:peak:)`. Never
 * hit-tested; they only draw.
 */
@Composable
private fun Scrims(bottomPeak: Float) {
  Box(Modifier.fillMaxSize()) {
    Box(
      Modifier
        .align(Alignment.TopCenter)
        .fillMaxWidth()
        .height(TOP_SCRIM_HEIGHT)
        .background(scrim(TOP_SCRIM_PEAK, fromTop = true)),
    )
    Box(
      Modifier
        .align(Alignment.BottomCenter)
        .fillMaxWidth()
        .height(BOTTOM_SCRIM_HEIGHT)
        .background(scrim(bottomPeak, fromTop = false)),
    )
  }
}

/** Plum at [peak] on its edge, 0.8 of it halfway, clear at the far end. */
private fun scrim(peak: Float, fromTop: Boolean): Brush {
  val stops = arrayOf(
    0f to Color.deepPlum.copy(alpha = peak),
    SCRIM_MID_STOP to Color.deepPlum.copy(alpha = peak * SCRIM_MID_SHARE),
    1f to Color.deepPlum.copy(alpha = 0f),
  )
  return if (fromTop) {
    Brush.verticalGradient(*stops)
  } else {
    Brush.verticalGradient(*stops, startY = Float.POSITIVE_INFINITY, endY = 0f)
  }
}

// MARK: - Chrome

/**
 * The onboarding back button's frosted cream circle, here closing the player
 * back into the mini pill. The swipe down and predictive back close it too.
 */
@Composable
private fun CloseButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
  val label = stringResource(R.string.player_close)
  Box(
    modifier
      .size(CLOSE_SIZE)
      .frostedCard(cornerRadius = Dp.chip)
      .softPress()
      .clickable(
        interactionSource = null,
        indication = null,
        role = Role.Button,
        onClick = onClick,
      )
      .semantics { contentDescription = label },
    contentAlignment = Alignment.Center,
  ) {
    Icon(SoundIcons.ChevronBack, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(CLOSE_GLYPH))
  }
}

/** Title, scrubber, transport and volume — the player, over the photograph's lower part. */
@Composable
private fun Controls(
  player: SoundPlaying,
  playback: SoundPlayback,
  listenReporter: ListenReporting,
  playlistStore: PlaylistStore,
  onShowLyrics: () -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(
    modifier
      .fillMaxWidth()
      .padding(bottom = CONTROLS_BOTTOM),
    verticalArrangement = Arrangement.spacedBy(CONTROLS_SPACING),
  ) {
    TitleRow(playback, listenReporter, playlistStore, onShowLyrics)
    Scrubber(player, playback.duration)
    Transport(player, playback)
    Volume(player, playback.volume)
  }
}

/**
 * The collection, the track and its subtitle, with Lyrics and Save trailing.
 * The subtitle gives way, for a few seconds, to a listen's heart when one
 * lands, and an earned heart blooms out of the titles.
 */
@Composable
private fun TitleRow(
  playback: SoundPlayback,
  listenReporter: ListenReporting,
  playlistStore: PlaylistStore,
  onShowLyrics: () -> Unit,
) {
  val playlist by playlistStore.state.collectAsStateWithLifecycle()
  val notice by listenReporter.notice.collectAsStateWithLifecycle()
  val bloom = rememberListenHeart(listenReporter, notice)
  val scope = rememberCoroutineScope()
  val track = playback.currentTrack
  val collection = playback.collection
  val secondary = Color.moonCream.copy(alpha = SECONDARY_ALPHA)

  Row(
    horizontalArrangement = Arrangement.spacedBy(TITLE_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    // Greedy rather than a Spacer, so the titles take the room they have. The
    // heart is felt by `rememberListenHeart`, so the bloom stays silent.
    HeartBurst(trigger = bloom, haptic = false, modifier = Modifier.weight(1f)) {
      Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(TITLE_SPACING)) {
        Text(
          text = collection?.title.orEmpty().uppercase(),
          style = COLLECTION_STYLE,
          color = secondary,
          maxLines = 1,
          overflow = TextOverflow.Ellipsis,
        )
        Text(
          text = track?.title.orEmpty(),
          style = TRACK_TITLE_STYLE,
          color = Color.moonCream,
          maxLines = 1,
          overflow = TextOverflow.Ellipsis,
        )
        ListenNoticeLine(
          notice = notice,
          label = { ListenNoticeLabel(it, style = DeepType.body, ink = Color.moonCream) },
        ) {
          Text(
            text = collection?.subtitle.orEmpty(),
            style = DeepType.body,
            color = secondary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
          )
        }
      }
    }

    // Lyrics — opens the (multi-language) lyrics sheet for the current track.
    ModeButton(
      icon = PlayerIcons.Lyrics,
      label = stringResource(R.string.player_lyrics),
      isOn = true,
      onClick = onShowLyrics,
    )
    if (track != null && collection != null) {
      // Keyed on the store's state, so a save anywhere refills the mark here.
      val saved = remember(playlist, track.id) { playlistStore.isSaved(track.id) }
      SaveTrackButton(
        saved = saved,
        onToggle = { scope.launch { playlistStore.toggle(track, collection) } },
      )
    }
  }
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
  val clock = Color.moonCream.copy(alpha = SECONDARY_ALPHA)

  Column(verticalArrangement = Arrangement.spacedBy(SCRUBBER_SPACING)) {
    SoundSlider(
      value = progress,
      onValueChange = { scrub = it },
      onValueChangeFinished = {
        scrub?.let { player.seek(it.toDouble()) }
        scrub = null
      },
      activeColor = Color.moonCream,
      trackHeight = SLIDER_TRACK,
      modifier = Modifier.semantics { contentDescription = label },
    )
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
      Text(SoundTime.clock(shownElapsed), style = CLOCK_STYLE, color = clock)
      Text(
        REMAINING_PREFIX + SoundTime.clock(maxOf(0.0, duration - shownElapsed)),
        style = CLOCK_STYLE,
        color = clock,
      )
    }
  }
}

/** Shuffle · Previous · Play/Pause · Next · Repeat. */
@Composable
private fun Transport(player: SoundPlaying, playback: SoundPlayback) {
  val on = stringResource(R.string.player_mode_on)
  val off = stringResource(R.string.player_mode_off)
  val repeatState = stringResource(
    when (playback.repeatMode) {
      RepeatMode.Off -> R.string.player_mode_off
      RepeatMode.All -> R.string.player_repeat_all
      RepeatMode.One -> R.string.player_repeat_one
    },
  )

  Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
    ModeButton(
      icon = SoundIcons.Shuffle,
      label = stringResource(R.string.player_shuffle),
      isOn = playback.isShuffled,
      state = if (playback.isShuffled) on else off,
      onClick = player::toggleShuffled,
    )

    Spacer(Modifier.weight(1f))

    SkipButton(PlayerIcons.Previous, stringResource(R.string.player_previous), player::previous)
    PlayPauseButton(
      isPlaying = playback.isPlaying,
      onClick = player::togglePlayPause,
      modifier = Modifier.padding(horizontal = PLAY_AIR),
    )
    SkipButton(PlayerIcons.Next, stringResource(R.string.player_next), player::next)

    Spacer(Modifier.weight(1f))

    // Off → all → one, as in Apple Music. Lit whenever a queue will repeat.
    ModeButton(
      icon = if (playback.repeatMode == RepeatMode.One) PlayerIcons.RepeatOne else PlayerIcons.Repeat,
      label = stringResource(R.string.player_repeat),
      isOn = playback.repeatMode != RepeatMode.Off,
      state = repeatState,
      onClick = player::cycleRepeatMode,
    )
  }
}

/** The player's own gain between its two speakers. */
@Composable
private fun Volume(player: SoundPlaying, volume: Double) {
  val ink = Color.moonCream.copy(alpha = SECONDARY_ALPHA)
  val label = stringResource(R.string.player_volume)
  Row(
    horizontalArrangement = Arrangement.spacedBy(VOLUME_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(PlayerIcons.Speaker, contentDescription = null, tint = ink, modifier = Modifier.size(SPEAKER_GLYPH))
    SoundSlider(
      value = volume.toFloat(),
      onValueChange = { player.setVolume(it.toDouble()) },
      activeColor = Color.moonCream.copy(alpha = VOLUME_FILL_ALPHA),
      trackHeight = SLIDER_TRACK,
      modifier = Modifier.weight(1f).semantics { contentDescription = label },
    )
    Icon(PlayerIcons.SpeakerWave, contentDescription = null, tint = ink, modifier = Modifier.size(SPEAKER_GLYPH))
  }
}

// MARK: - Buttons

/**
 * The cream disc at the heart of the transport, its glyph swapping in a
 * crossfade — iOS's `.contentTransition(.symbolEffect(.replace))`.
 */
@Composable
private fun PlayPauseButton(isPlaying: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
  val label = stringResource(if (isPlaying) R.string.player_pause else R.string.player_play)
  Box(
    modifier
      .size(PLAY_SIZE)
      .softPress()
      .clip(CircleShape)
      .background(Color.moonCream)
      .clickable(
        interactionSource = null,
        indication = null,
        role = Role.Button,
        onClick = onClick,
      )
      .semantics { contentDescription = label },
    contentAlignment = Alignment.Center,
  ) {
    Crossfade(targetState = isPlaying, animationSpec = exhale(), label = "now-playing-play-pause") { playing ->
      Icon(
        imageVector = if (playing) PlayerIcons.Pause else PlayerIcons.Play,
        contentDescription = null,
        tint = Color.deepPlum,
        modifier = Modifier.size(PLAY_GLYPH),
      )
    }
  }
}

/** Previous or Next: a bare cream glyph in a generous target. */
@Composable
private fun SkipButton(icon: ImageVector, label: String, onClick: () -> Unit) {
  Box(
    Modifier
      .size(SKIP_TARGET)
      .softPress()
      .clickable(
        interactionSource = null,
        indication = null,
        role = Role.Button,
        onClick = onClick,
      ),
    contentAlignment = Alignment.Center,
  ) {
    Icon(icon, contentDescription = label, tint = Color.moonCream, modifier = Modifier.size(SKIP_GLYPH))
  }
}

/**
 * Shuffle, Repeat and Lyrics. [isOn] lights a mode in full cream, the ink the
 * title wears; off, it steps back to half. The ink and the glyph both change
 * on DEEP's [exhale]. [state] is what TalkBack reads after the [label] — "On",
 * "All" — as VoiceOver reads iOS's `accessibilityValue`.
 */
@Composable
private fun ModeButton(
  icon: ImageVector,
  label: String,
  isOn: Boolean,
  onClick: () -> Unit,
  state: String? = null,
) {
  val tint by animateColorAsState(
    targetValue = if (isOn) Color.moonCream else Color.moonCream.copy(alpha = MODE_OFF_ALPHA),
    animationSpec = exhale(),
    label = "now-playing-mode-tint",
  )
  Box(
    Modifier
      .size(MODE_TARGET)
      .softPress()
      .clickable(
        interactionSource = null,
        indication = null,
        role = Role.Button,
        onClick = onClick,
      )
      .semantics {
        contentDescription = label
        if (state != null) stateDescription = state
      },
    contentAlignment = Alignment.Center,
  ) {
    Crossfade(targetState = icon, animationSpec = exhale(), label = "now-playing-mode-glyph") { glyph ->
      Icon(glyph, contentDescription = null, tint = tint, modifier = Modifier.size(MODE_GLYPH))
    }
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Now Playing — playing")
@Composable
private fun NowPlayingPlayingPreview() {
  DeepTheme {
    NowPlayingScreen(
      player = remember { MockSoundPlayer.playing() },
      listenReporter = remember { MockListenReporter() },
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
      listenReporter = remember { MockListenReporter() },
      playlistStore = remember { MockPlaylistStore.empty },
      library = remember { MockSoundLibrary.loaded },
      onCollapse = {},
    )
  }
}

@Preview(showBackground = true, name = "Now Playing — Shuffle, Repeat One")
@Composable
private fun NowPlayingShuffleRepeatOnePreview() {
  DeepTheme {
    NowPlayingScreen(
      player = remember { MockSoundPlayer.playing(repeatMode = RepeatMode.One, isShuffled = true) },
      listenReporter = remember { MockListenReporter() },
      playlistStore = remember { MockPlaylistStore.empty },
      library = remember { MockSoundLibrary.loaded },
      onCollapse = {},
    )
  }
}

@Preview(showBackground = true, name = "Now Playing — Repeat All, saved")
@Composable
private fun NowPlayingRepeatAllSavedPreview() {
  val player = remember { MockSoundPlayer.playing(repeatMode = RepeatMode.All) }
  val store = remember {
    MockPlaylistStore(PlaylistState.Loaded(listOfNotNull(player.playback.value.currentEntry)))
  }
  DeepTheme {
    NowPlayingScreen(
      player = player,
      listenReporter = remember { MockListenReporter() },
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
      listenReporter = remember { MockListenReporter() },
      playlistStore = remember { MockPlaylistStore.empty },
      library = remember { MockSoundLibrary.loaded },
      onCollapse = {},
    )
  }
}

@Preview(showBackground = true, name = "Now Playing — heart earned")
@Composable
private fun NowPlayingHeartEarnedPreview() {
  DeepTheme {
    NowPlayingScreen(
      player = remember { MockSoundPlayer.playing() },
      listenReporter = remember { MockListenReporter.earned() },
      playlistStore = remember { MockPlaylistStore.empty },
      library = remember { MockSoundLibrary.loaded },
      onCollapse = {},
    )
  }
}

@Preview(showBackground = true, name = "Now Playing — today's hearts in, Thai", locale = "th")
@Composable
private fun NowPlayingDayCompletePreview() {
  DeepTheme {
    NowPlayingScreen(
      player = remember { MockSoundPlayer.playing() },
      listenReporter = remember { MockListenReporter.dayComplete() },
      playlistStore = remember { MockPlaylistStore.empty },
      library = remember { MockSoundLibrary.loaded },
      onCollapse = {},
    )
  }
}
