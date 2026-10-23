package io.appbeyond.freelance.deep.feature.deepsound.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.PlayerIcons
import io.appbeyond.freelance.deep.feature.deepsound.player.MockSoundPlayer
import io.appbeyond.freelance.deep.feature.deepsound.player.SoundPlaying
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

/**
 * The pill's whole height — iOS's `.frame(height: 48)`. The capsule carries no
 * vertical padding of its own, so this is also what the shell reserves above
 * [io.appbeyond.freelance.deep.feature.appshell.DeepBottomBar] (plus its gap)
 * for content to clear.
 */
val MiniPlayerPillHeight: Dp = 48.dp

/** The capsule silhouette — the frosted surface, the clip and the touch shape. */
private val CAPSULE = RoundedCornerShape(Dp.chip)

/** The track title — iOS's `DeepType.caption.weight(.medium)`. */
private val TITLE_STYLE = DeepType.caption.copy(fontWeight = FontWeight.Medium)

/** iOS's `.padding(.horizontal, 12)`. */
private val CONTENT_PADDING = 12.dp

/** iOS's `HStack(spacing: 10)`. */
private val ITEM_SPACING = 10.dp

/** iOS's `Spacer(minLength: 8)` between the titles and the transport. */
private val TITLE_TRAILING_AIR = 8.dp

/** The collection artwork — iOS's 36pt frame, corner radius 8. */
private val ARTWORK_SIZE = 36.dp
private val ARTWORK_RADIUS = 8.dp

/** Each transport glyph's hit target — iOS's `.frame(width: 40, height: 40)`. */
private val TRANSPORT_TARGET = 40.dp
private val PLAY_PAUSE_GLYPH = 20.dp
private val NEXT_GLYPH = 18.dp

/** The progress line — iOS's `Capsule().fill(.lavenderMist.opacity(0.7)).frame(height: 2)`. */
private val PROGRESS_HEIGHT = 2.dp
private const val PROGRESS_ALPHA = 0.7f

/**
 * How far a swipe up must travel to count as all the way open. The shell maps
 * the reported fraction onto its seekable transition; about a third of a
 * phone's height, which is where an upward flick naturally runs out.
 */
private val EXPAND_DRAG_DISTANCE = 300.dp

// MARK: - Pill

/**
 * The mini player: a floating frosted capsule the shell parks 8dp above
 * [io.appbeyond.freelance.deep.feature.appshell.DeepBottomBar] while a track is
 * loaded. Ported from `Deep/Deep/Features/DeepSound/Components/MiniPlayerBar.swift`
 * and `Player/PlayerAccessoryView.swift`.
 *
 * On iOS this is pure content inside the tab bar's bottom accessory, and the
 * system supplies the Liquid Glass capsule. Android has no tab accessory, so
 * the pill draws its own surface ([frostedCard] at the chip radius) and clips
 * its content and progress line to the same curve. iOS's inline variant
 * (`MiniPlayerInlineBar`, for a minimized tab bar) has no counterpart —
 * [DeepBottomBar][io.appbeyond.freelance.deep.feature.appshell.DeepBottomBar]
 * never minimizes.
 *
 * Tapping anywhere but the two transport glyphs asks for Now Playing via
 * [onExpand]; so does a swipe up, which reports its progress instead so the
 * shell can scrub the morph under the finger. This leaf hosts no
 * `SharedTransitionLayout` or transition state of its own — the shell owns
 * both and threads the shared-element modifier in through [artworkModifier].
 *
 * The progress line reads [SoundPlaying.elapsed] only in the draw phase, so its
 * four-a-second tick redraws a 2dp line rather than recomposing the pill.
 *
 * @param artworkModifier applied first on the artwork, before its size — where
 *   the shell attaches `Modifier.sharedElement(...)`.
 * @param onDragUp the swipe's progress, 0…1, over a [EXPAND_DRAG_DISTANCE]
 *   travel. Downward travel clamps to 0.
 * @param onDragUpEnd the release velocity in px/s, positive upward (toward
 *   open). A cancelled drag reports 0 so the shell settles on the fraction alone.
 */
@Composable
fun MiniPlayerPill(
  player: SoundPlaying,
  onExpand: () -> Unit,
  modifier: Modifier = Modifier,
  artworkModifier: Modifier = Modifier,
  onDragUp: (fraction: Float) -> Unit = {},
  onDragUpEnd: (velocity: Float) -> Unit = {},
) {
  val playback by player.playback.collectAsStateWithLifecycle()
  // Kept as a State and read only inside `drawWithContent` below.
  val elapsed = player.elapsed.collectAsStateWithLifecycle()
  val duration = rememberUpdatedState(playback.duration)
  val onUp by rememberUpdatedState(onDragUp)
  val onUpEnd by rememberUpdatedState(onDragUpEnd)

  val track = playback.currentTrack
  val collection = playback.collection
  val title = track?.title ?: stringResource(R.string.player_not_playing)
  val description = stringResource(R.string.player_now_playing_a11y, track?.title.orEmpty())

  Box(
    modifier
      .fillMaxWidth()
      .height(MiniPlayerPillHeight)
      .frostedCard(cornerRadius = Dp.chip)
      // Content and progress line clip together, so the full-width line is
      // trimmed by the same curve the surface draws.
      .clip(CAPSULE)
      .drawWithContent {
        drawContent()
        val progress = if (duration.value > 0) (elapsed.value / duration.value).coerceIn(0.0, 1.0) else 0.0
        val line = PROGRESS_HEIGHT.toPx()
        drawRoundRect(
          color = Color.lavenderMist.copy(alpha = PROGRESS_ALPHA),
          topLeft = Offset(0f, size.height - line),
          size = Size(size.width * progress.toFloat(), line),
          cornerRadius = CornerRadius(line / 2f),
        )
      }
      .pointerInput(Unit) {
        val distance = EXPAND_DRAG_DISTANCE.toPx()
        val tracker = VelocityTracker()
        var travelled = 0f
        detectVerticalDragGestures(
          onDragStart = {
            travelled = 0f
            tracker.resetTracking()
          },
          onDragEnd = { onUpEnd(-tracker.calculateVelocity().y) },
          onDragCancel = { onUpEnd(0f) },
          onVerticalDrag = { change, dragAmount ->
            change.consume()
            travelled += dragAmount
            // Tracked on the accumulated travel, not the pointer's local
            // position: the shell may be moving this very pill under the finger.
            tracker.addPosition(change.uptimeMillis, Offset(0f, travelled))
            onUp((-travelled / distance).coerceIn(0f, 1f))
          },
        )
      }
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        role = Role.Button,
        onClick = onExpand,
      )
      .semantics { contentDescription = description },
  ) {
    Row(
      Modifier.fillMaxSize().padding(horizontal = CONTENT_PADDING),
      horizontalArrangement = Arrangement.spacedBy(ITEM_SPACING),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      ArtworkImage(
        url = collection?.imageUrl,
        palette = collection?.palette,
        modifier = artworkModifier
          .size(ARTWORK_SIZE)
          .clip(RoundedCornerShape(ARTWORK_RADIUS))
          .clearAndSetSemantics {},
      )

      // Greedy rather than a Spacer, so a long title takes the room it has.
      Column(
        Modifier
          .weight(1f)
          .padding(end = TITLE_TRAILING_AIR)
          .clearAndSetSemantics {},
      ) {
        Text(
          text = title,
          style = TITLE_STYLE,
          color = Color.deepPlum,
          maxLines = 1,
          overflow = TextOverflow.Ellipsis,
        )
        Text(
          text = collection?.title.orEmpty(),
          style = DeepType.micro,
          color = Color.driftGrey,
          maxLines = 1,
          overflow = TextOverflow.Ellipsis,
        )
      }

      TransportGlyph(
        icon = if (playback.isPlaying) PlayerIcons.Pause else PlayerIcons.Play,
        glyphSize = PLAY_PAUSE_GLYPH,
        label = stringResource(if (playback.isPlaying) R.string.player_pause else R.string.player_play),
        onClick = player::togglePlayPause,
      )
      TransportGlyph(
        icon = PlayerIcons.Next,
        glyphSize = NEXT_GLYPH,
        label = stringResource(R.string.player_next),
        onClick = player::next,
      )
    }
  }
}

/**
 * A bare transport glyph with a generous target that doesn't trigger the
 * surrounding expand — iOS's private `transportButton`.
 */
@Composable
private fun TransportGlyph(
  icon: ImageVector,
  glyphSize: Dp,
  label: String,
  onClick: () -> Unit,
) {
  Box(
    Modifier
      .size(TRANSPORT_TARGET)
      .softPress()
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        role = Role.Button,
        onClick = onClick,
      ),
    contentAlignment = Alignment.Center,
  ) {
    Icon(icon, contentDescription = label, tint = Color.deepPlum, modifier = Modifier.size(glyphSize))
  }
}

// MARK: - Previews

/**
 * The shipped pill floats over whatever tab is showing; previews stand that in
 * with the atmosphere so the frosted surface reads in context.
 */
@Composable
private fun PillPreviewFrame(player: SoundPlaying) {
  DeepTheme {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
      AtmosphereBackground(animated = false)
      MiniPlayerPill(player = player, onExpand = {}, modifier = Modifier.padding(horizontal = Dp.edge))
    }
  }
}

@Preview(showBackground = true, name = "Mini player — playing")
@Composable
private fun MiniPlayerPillPlayingPreview() {
  PillPreviewFrame(remember { MockSoundPlayer.playing() })
}

@Preview(showBackground = true, name = "Mini player — paused")
@Composable
private fun MiniPlayerPillPausedPreview() {
  PillPreviewFrame(remember { MockSoundPlayer.playing().apply { togglePlayPause() } })
}

@Preview(showBackground = true, name = "Mini player — idle")
@Composable
private fun MiniPlayerPillIdlePreview() {
  PillPreviewFrame(remember { MockSoundPlayer.idle() })
}
