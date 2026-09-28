package io.appbeyond.freelance.deep.feature.playlist.components

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.PlayerIcons
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

/** The soft circle — iOS's `.frame(width: 34, height: 34)`. */
private val BUTTON_SIZE = 34.dp

/** The bookmark itself — iOS's `.subheadline` glyph, semibold. */
private val GLYPH_SIZE = 16.dp

/** The circle's fill — iOS's `.white.opacity(0.4)`. */
private const val FILL_ALPHA = 0.4f

// MARK: - Button

/**
 * The bookmark that saves a sound to the playlist — Now Playing's one utility
 * control, in the soft translucent circle the screen already draws. Ported
 * from `Deep/Deep/Features/Playlist/Components/SaveTrackButton.swift`.
 *
 * A bookmark rather than a heart on purpose: a filled blush heart is the
 * Compassion currency everywhere else in Deep, and the same mark cannot mean
 * two things.
 *
 * Stateless where iOS reads the store from the environment: the caller knows
 * [saved] (from `PlaylistStore.isSaved`, read under the store's `state` so it
 * recomposes) and launches the suspend `toggle` in [onToggle]. The store is
 * optimistic, so the mark fills the moment it's tapped.
 *
 * Plum when kept — the same ink Now Playing's transport wears — so the filled
 * mark reads as *more* present than the empty grey one. Lavender would sink
 * into the screen's own lavender wash and read as less.
 */
@Composable
fun SaveTrackButton(
  saved: Boolean,
  onToggle: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val label = stringResource(if (saved) R.string.player_saved_to_playlist else R.string.player_save_to_playlist)
  val hint = stringResource(if (saved) R.string.player_save_hint_remove else R.string.player_save_hint_add)

  Box(
    modifier = modifier
      .size(BUTTON_SIZE)
      .softPress()
      .clip(CircleShape)
      .background(Color.White.copy(alpha = FILL_ALPHA))
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        role = Role.Button,
        onClickLabel = hint,
        onClick = onToggle,
      )
      .semantics { contentDescription = label },
    contentAlignment = Alignment.Center,
  ) {
    // iOS's `.contentTransition(.symbolEffect(.replace))` under `.exhale`.
    Crossfade(targetState = saved, animationSpec = exhale(), label = "save-track-glyph") { isSaved ->
      Icon(
        imageVector = if (isSaved) PlayerIcons.BookmarkFilled else PlayerIcons.Bookmark,
        contentDescription = null,
        tint = if (isSaved) Color.deepPlum else Color.driftGrey,
        modifier = Modifier.size(GLYPH_SIZE),
      )
    }
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Save track — saved and not")
@Composable
private fun SaveTrackButtonPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
      AtmosphereBackground(animated = false)
      Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
        SaveTrackButton(saved = false, onToggle = {})
        SaveTrackButton(saved = true, onToggle = {})
      }
    }
  }
}

@Preview(showBackground = true, name = "Save track — interactive")
@Composable
private fun SaveTrackButtonInteractivePreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
      AtmosphereBackground(animated = false)
      var saved by remember { mutableStateOf(false) }
      SaveTrackButton(saved = saved, onToggle = { saved = !saved })
    }
  }
}
