package io.appbeyond.freelance.deep.feature.playlist.components

import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MenuDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTime
import io.appbeyond.freelance.deep.feature.playlist.store.PlaylistFixtures
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.softPress
import io.appbeyond.freelance.deep.theme.tile

// MARK: - Constants

/** iOS's `.padding(12)` inside the card. */
private val ROW_PADDING = 12.dp

/** iOS's `HStack(spacing: 14)`. */
private val ROW_SPACING = 14.dp

/** The collection artwork — iOS's 56pt frame, corner radius 14. */
internal val PLAYLIST_ARTWORK_SIZE = 56.dp
internal val PLAYLIST_ARTWORK_RADIUS = 14.dp

/** iOS's `VStack(spacing: 3)` of title, collection and duration. */
private val TEXT_SPACING = 3.dp

/** The duration ticks nowhere, but its digits still line up down the list — iOS's `.monospacedDigit()`. */
private val DURATION_STYLE = DeepType.micro.copy(fontFeatureSettings = "tnum")

/** The remove menu's glyph. */
private val MENU_GLYPH = 18.dp

// MARK: - Row

/**
 * One saved sound: the artwork of the collection it came from, its title, that
 * collection's name, and how long it runs. The frosted-card list row DEEP uses
 * for collections, sized down for a track. Ported from
 * `Deep/Deep/Features/Playlist/Components/PlaylistTrackRow.swift`.
 *
 * Taking a sound out lives in the long-press menu — iOS's `contextMenu`, the
 * same gesture that saved it — so the row itself carries nothing but the
 * sound. TalkBack gets the removal as a custom action instead of a gesture it
 * can't discover. No destructive red on it: DEEP has no urgent reds, and taking
 * a sound out is one tap from saving it again.
 *
 * iOS also draws a lock for premium sounds here. Android plays everything, so
 * there is no lock — a deliberate divergence.
 *
 * @param isCurrent true while this is the sound playing, which tints the title
 *   the way a collection's track list does.
 */
@Composable
fun PlaylistTrackRow(
  entry: SoundQueueEntry,
  isCurrent: Boolean,
  onPlay: () -> Unit,
  onRemove: () -> Unit,
  modifier: Modifier = Modifier,
) {
  var menuOpen by remember { mutableStateOf(false) }
  val haptics = LocalHapticFeedback.current
  val removeLabel = stringResource(R.string.playlist_remove)
  val description = stringResource(R.string.playlist_row_a11y, entry.track.title, entry.collection.title)

  Box(modifier) {
    Row(
      Modifier
        .fillMaxWidth()
        .softPress()
        .frostedCard()
        .combinedClickable(
          interactionSource = remember { MutableInteractionSource() },
          indication = null,
          role = Role.Button,
          onLongClickLabel = removeLabel,
          onLongClick = {
            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            menuOpen = true
          },
          onClick = onPlay,
        )
        .semantics {
          contentDescription = description
          customActions = listOf(CustomAccessibilityAction(removeLabel) { onRemove(); true })
        }
        .padding(ROW_PADDING),
      horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      ArtworkImage(
        url = entry.collection.imageUrl,
        palette = entry.collection.palette,
        modifier = Modifier
          .size(PLAYLIST_ARTWORK_SIZE)
          .clip(RoundedCornerShape(PLAYLIST_ARTWORK_RADIUS))
          .clearAndSetSemantics {},
      )

      // A Spacer here would bid against this column and truncate titles that
      // had room; a greedy weight lets the text take what it needs.
      Column(
        Modifier.weight(1f).clearAndSetSemantics {},
        verticalArrangement = Arrangement.spacedBy(TEXT_SPACING),
      ) {
        Text(
          text = entry.track.title,
          style = DeepType.bodyMedium,
          color = if (isCurrent) Color.lavenderMist else Color.deepPlum,
          maxLines = 1,
          overflow = TextOverflow.Ellipsis,
        )
        Text(
          text = entry.collection.title,
          style = DeepType.caption,
          color = Color.driftGrey,
          maxLines = 1,
          overflow = TextOverflow.Ellipsis,
        )
        Text(
          text = SoundTime.clock(entry.track.durationSeconds.toDouble()),
          style = DURATION_STYLE,
          color = Color.driftGrey,
        )
      }
    }

    DropdownMenu(
      expanded = menuOpen,
      onDismissRequest = { menuOpen = false },
      shape = RoundedCornerShape(Dp.tile),
      containerColor = Color.moonCream,
      tonalElevation = 0.dp,
    ) {
      DropdownMenuItem(
        text = { Text(removeLabel, style = DeepType.body) },
        leadingIcon = {
          Icon(SoundIcons.BookmarkSlash, contentDescription = null, modifier = Modifier.size(MENU_GLYPH))
        },
        colors = MenuDefaults.itemColors(textColor = Color.deepPlum, leadingIconColor = Color.driftGrey),
        onClick = {
          menuOpen = false
          onRemove()
        },
      )
    }
  }
}

// MARK: - Preview

@Preview(showBackground = true, name = "Playlist row")
@Composable
private fun PlaylistTrackRowPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize()) {
      AtmosphereBackground(animated = false)
      Column(
        Modifier.padding(horizontal = Dp.edge).padding(top = Dp.edge),
        verticalArrangement = Arrangement.spacedBy(ROW_SPACING),
      ) {
        PlaylistTrackRow(entry = PlaylistFixtures.saved[0], isCurrent = false, onPlay = {}, onRemove = {})
        PlaylistTrackRow(entry = PlaylistFixtures.saved[1], isCurrent = true, onPlay = {}, onRemove = {})
        PlaylistTrackRow(entry = PlaylistFixtures.saved[2], isCurrent = false, onPlay = {}, onRemove = {})
      }
    }
  }
}
