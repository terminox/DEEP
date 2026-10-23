package io.appbeyond.freelance.deep.feature.deepsound

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.components.LyricsSkeleton
import io.appbeyond.freelance.deep.feature.deepsound.model.LyricsSelection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTrack
import io.appbeyond.freelance.deep.feature.deepsound.model.TrackLyrics
import io.appbeyond.freelance.deep.feature.deepsound.store.MockSoundLibrary
import io.appbeyond.freelance.deep.feature.deepsound.store.SoundLibrary
import io.appbeyond.freelance.deep.shared.components.DeepChip
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import kotlinx.coroutines.CancellationException

// MARK: - Constants

/** iOS's `.lineSpacing(8)` — extra leading on top of the body's own 1.6. */
private const val LYRICS_EXTRA_LEADING_SP = 8f

/** iOS's `.padding(.bottom, 60)` — room to scroll the last line off the edge. */
private val CONTENT_BOTTOM_PADDING = 60.dp

/** iOS's `.padding(.vertical, 40)` around the empty line. */
private val EMPTY_PADDING_VERTICAL = 40.dp

private val CHIP_SPACING = 8.dp

/** The grabber's tint — a soft lavender pill, never a rule across the sheet. */
private const val HANDLE_ALPHA = 0.5f

// MARK: - Load state

/**
 * Loading, then whatever came back. A failed fetch lands on an empty [Loaded],
 * as iOS's `try?` does: to a listener, "the lyrics didn't arrive" and "there
 * are no lyrics" are the same calm empty line.
 */
private sealed interface LyricsLoad {
  data object Loading : LyricsLoad
  data class Loaded(val lyrics: List<TrackLyrics>) : LyricsLoad
}

// MARK: - Sheet

/**
 * The lyrics for a track, opened from Now Playing: a gentle language switch
 * when more than one language exists, and a calm empty line when none do.
 *
 * Ported from Deep/Deep/Features/DeepSound/Components/LyricsSheet.swift. A
 * Material3 [ModalBottomSheet] dressed in DEEP's tokens — a moonCream surface
 * with the card radius and a soft lavender grabber, no tonal tint, no scrim
 * rule. The language picker is the app's [DeepChip] rather than iOS's bespoke
 * capsules, which are the same selectable word in a different coat.
 *
 * Keyed to the track it opened with: if the queue moves on underneath an open
 * sheet, the lyrics start over for the new track rather than showing the old
 * one's.
 *
 * @param track the track whose lyrics to show.
 * @param library where the lyrics come from.
 * @param onDismiss the sheet was swiped or tapped away.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LyricsSheet(
  track: SoundTrack,
  library: SoundLibrary,
  onDismiss: () -> Unit,
) {
  ModalBottomSheet(
    onDismissRequest = onDismiss,
    sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    shape = RoundedCornerShape(topStart = Dp.card, topEnd = Dp.card),
    containerColor = Color.moonCream,
    contentColor = Color.deepPlum,
    tonalElevation = 0.dp,
    dragHandle = {
      BottomSheetDefaults.DragHandle(color = Color.lavenderMist.copy(alpha = HANDLE_ALPHA))
    },
  ) {
    LyricsContent(track = track, library = library)
  }
}

/** The sheet's body — the fetch, the picker and the text. */
@Composable
private fun LyricsContent(track: SoundTrack, library: SoundLibrary) {
  var load by remember(track.id) { mutableStateOf<LyricsLoad>(LyricsLoad.Loading) }
  var selected by remember(track.id) { mutableStateOf<String?>(null) }

  LaunchedEffect(track.id, library) {
    load = LyricsLoad.Loading
    val fetched = try {
      library.lyrics(track.id)
    } catch (e: CancellationException) {
      throw e
    } catch (e: Exception) {
      emptyList()
    }
    selected = fetched.firstOrNull()?.languageCode
    load = LyricsLoad.Loaded(fetched)
  }

  LyricsBody(
    title = track.title,
    load = load,
    selected = selected,
    onSelect = { selected = it },
  )
}

@Composable
private fun LyricsBody(
  title: String,
  load: LyricsLoad,
  selected: String?,
  onSelect: (String) -> Unit,
) {
  Column(
    Modifier
      .fillMaxWidth()
      .verticalScroll(rememberScrollState())
      .navigationBarsPadding()
      .padding(horizontal = Dp.edge)
      .padding(top = Dp.rhythm, bottom = CONTENT_BOTTOM_PADDING),
    verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
  ) {
    Text(title, style = DeepType.displayTitle, color = Color.deepPlum)

    val lyrics = (load as? LyricsLoad.Loaded)?.lyrics.orEmpty()
    if (LyricsSelection.showsLanguagePicker(lyrics)) {
      Row(horizontalArrangement = Arrangement.spacedBy(CHIP_SPACING)) {
        lyrics.forEach { lyric ->
          DeepChip(
            label = lyric.languageCode.uppercase(),
            isSelected = lyric.languageCode == selected,
            onClick = { onSelect(lyric.languageCode) },
          )
        }
      }
    }

    Crossfade(targetState = load, animationSpec = bloom(), label = "lyrics") { state ->
      when (state) {
        LyricsLoad.Loading -> LyricsSkeleton()
        is LyricsLoad.Loaded -> {
          val current = LyricsSelection.select(state.lyrics, selected)
          if (current != null) {
            Text(
              text = current.content,
              style = DeepType.body.copy(
                lineHeight = (DeepType.body.lineHeight.value + LYRICS_EXTRA_LEADING_SP).sp,
              ),
              color = Color.deepPlum,
              modifier = Modifier.fillMaxWidth(),
            )
          } else {
            Text(
              text = stringResource(R.string.deepsound_lyrics_empty),
              style = DeepType.body,
              color = Color.driftGrey,
              textAlign = TextAlign.Center,
              modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = EMPTY_PADDING_VERTICAL),
            )
          }
        }
      }
    }
  }
}

// MARK: - Previews

/*
 * The sheet itself previews poorly — a ModalBottomSheet opens in its own
 * window — so these render its body on the sheet's surface instead.
 */

/** The real sheet — run it in interactive mode; a static render shows only the host. */
@Preview(showBackground = true, name = "Lyrics sheet (interactive)")
@Composable
private fun LyricsSheetPreview() {
  DeepTheme {
    LyricsSheet(
      track = SoundFixtures.oceanDepths.tracks.first(),
      library = remember { MockSoundLibrary.loaded },
      onDismiss = {},
    )
  }
}

@Preview(showBackground = true, name = "Lyrics — two languages")
@Composable
private fun LyricsLoadedPreview() {
  var selected by remember { mutableStateOf<String?>("en") }
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      LyricsBody(
        title = SoundFixtures.oceanDepths.tracks.first().title,
        load = LyricsLoad.Loaded(
          listOf(
            TrackLyrics("en", "Breathe in slowly\nlet the tide come in\n\nBreathe out gently\nlet the tide go out"),
            TrackLyrics("th", "หายใจเข้าช้า ๆ\nปล่อยให้คลื่นเข้ามา\n\nหายใจออกเบา ๆ\nปล่อยให้คลื่นกลับไป"),
          ),
        ),
        selected = selected,
        onSelect = { selected = it },
      )
    }
  }
}

@Preview(showBackground = true, name = "Lyrics — loading")
@Composable
private fun LyricsLoadingPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      LyricsBody(title = "Drifting Tide", load = LyricsLoad.Loading, selected = null, onSelect = {})
    }
  }
}

@Preview(showBackground = true, name = "Lyrics — none")
@Composable
private fun LyricsEmptyPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      // MockSoundLibrary serves no lyrics, so this settles on the empty line.
      LyricsContent(
        track = SoundFixtures.oceanDepths.tracks.first(),
        library = remember { MockSoundLibrary.loaded },
      )
    }
  }
}
