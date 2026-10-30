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
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.PlayerIcons
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

/** The touch target — iOS's `.frame(width: 44, height: 44)`. */
private val BUTTON_SIZE = 44.dp

/** The bookmark itself — iOS's 18pt semibold glyph. */
private val GLYPH_SIZE = 18.dp

/** Not yet saved, the mark steps back to the subtitle's cream — iOS's `.moonCream.opacity(0.72)`. */
private const val UNSAVED_ALPHA = 0.72f

// MARK: - Button

/**
 * The bookmark that saves a sound to the playlist, set in moonlight over Now
 * Playing's full-screen photograph. Ported from
 * `Deep/Deep/Features/Playlist/Components/SaveTrackButton.swift`.
 *
 * A bookmark rather than a heart on purpose: a filled blush heart is the
 * Compassion currency everywhere else in DEEP, and the same mark cannot mean
 * two things.
 *
 * Stateless where iOS reads the store from the environment: the caller knows
 * [saved] (from `PlaylistStore.isSaved`, read under the store's `state` so it
 * recomposes) and launches the suspend `toggle` in [onToggle]. The store is
 * optimistic, so the mark fills the moment it's tapped.
 *
 * Full cream when kept — the ink the track title wears — so the filled mark
 * reads as *more* present than the empty one, which steps back to the
 * subtitle's softer cream. No circle behind it: the photograph and its scrim
 * are the surface.
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
        tint = if (isSaved) Color.moonCream else Color.moonCream.copy(alpha = UNSAVED_ALPHA),
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
    Box(Modifier.fillMaxSize().background(Color.deepPlum), contentAlignment = Alignment.Center) {
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
    Box(Modifier.fillMaxSize().background(Color.deepPlum), contentAlignment = Alignment.Center) {
      var saved by remember { mutableStateOf(false) }
      SaveTrackButton(saved = saved, onToggle = { saved = !saved })
    }
  }
}
