package io.appbeyond.freelance.deep.feature.playlist.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.SkeletonBlock
import io.appbeyond.freelance.deep.shared.components.SkeletonTextLine
import io.appbeyond.freelance.deep.shared.components.skeletonBreath
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.rhythm

// MARK: - Constants

/** Placeholder rows — enough to fill a first screen, never a count the listener will read as theirs. */
private const val ROW_COUNT = 4

/** The Play/Shuffle pair's stand-ins — iOS's `SkeletonBlock(cornerRadius: 16)` at 46pt, 12 apart. */
private val ACTION_HEIGHT = 46.dp
private val ACTION_RADIUS = 16.dp
private val ACTIONS_SPACING = 12.dp

/** Matches [PlaylistTrackRow]: `VStack(spacing: 14)`, `.padding(12)`, `HStack(spacing: 14)`. */
private val ROW_GAP = 14.dp
private val ROW_PADDING = 12.dp
private val ROW_SPACING = 14.dp

/** The two text lines — iOS's `SkeletonTextLine(width: 150)` / `(width: 96)`, 6 apart. */
private val TITLE_LINE = 150.dp
private val SUBTITLE_LINE = 96.dp
private val LINE_SPACING = 6.dp

/**
 * A breathing skeleton mirroring the loaded playlist, shown while the saved
 * sounds are fetched with nothing cached. Never a spinner and never a shimmer
 * sweep; the whole subtree breathes as one. Ported from
 * `Deep/Deep/Features/Playlist/Components/PlaylistSkeleton.swift`: the
 * Play/Shuffle pair, then four placeholder rows.
 */
@Composable
fun PlaylistSkeleton(modifier: Modifier = Modifier) {
  Column(
    modifier
      .fillMaxWidth()
      .padding(horizontal = Dp.edge)
      .skeletonBreath(),
    verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
  ) {
    Row(horizontalArrangement = Arrangement.spacedBy(ACTIONS_SPACING)) {
      SkeletonBlock(Modifier.weight(1f).height(ACTION_HEIGHT), cornerRadius = ACTION_RADIUS)
      SkeletonBlock(Modifier.weight(1f).height(ACTION_HEIGHT), cornerRadius = ACTION_RADIUS)
    }
    Column(verticalArrangement = Arrangement.spacedBy(ROW_GAP)) {
      repeat(ROW_COUNT) { SkeletonRow() }
    }
  }
}

@Composable
private fun SkeletonRow() {
  Row(
    Modifier
      .fillMaxWidth()
      .frostedCard()
      .padding(ROW_PADDING),
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    SkeletonBlock(Modifier.size(PLAYLIST_ARTWORK_SIZE), cornerRadius = PLAYLIST_ARTWORK_RADIUS)
    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(LINE_SPACING)) {
      SkeletonTextLine(width = TITLE_LINE)
      SkeletonTextLine(width = SUBTITLE_LINE)
    }
  }
}

// MARK: - Preview

@Preview(showBackground = true, name = "Playlist skeleton")
@Composable
private fun PlaylistSkeletonPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize()) {
      AtmosphereBackground(animated = false)
      PlaylistSkeleton(Modifier.padding(top = Dp.rhythm))
    }
  }
}
