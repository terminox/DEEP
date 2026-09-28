package io.appbeyond.freelance.deep.feature.deepsound.components

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.shared.components.SkeletonBlock
import io.appbeyond.freelance.deep.shared.components.SkeletonTextLine
import io.appbeyond.freelance.deep.shared.components.skeletonBreath
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm

private const val SKELETON_SHELVES = 2
private const val SKELETON_TILES = 3

private val SHELF_TITLE_WIDTH = 120.dp
private val TILE_TITLE_WIDTH = 110.dp
private val TILE_SUBTITLE_WIDTH = 70.dp

/**
 * A breathing skeleton mirroring the loaded home shelves — two carousels of
 * three placeholder tiles each, shown while the Deep Sound home fetches.
 *
 * Ported from Deep/Deep/Features/DeepSound/Components/SoundShelvesSkeleton.swift.
 * The tile row is wider than a phone, as the real row is; it sits in a
 * horizontal scroll that ignores the finger, so the third tile runs off the
 * edge at full size instead of being squeezed to fit.
 */
@Composable
fun SoundShelvesSkeleton(modifier: Modifier = Modifier) {
  Column(
    modifier
      .fillMaxWidth()
      .skeletonBreath(),
    verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
  ) {
    repeat(SKELETON_SHELVES) { ShelfSkeleton() }
  }
}

@Composable
private fun ShelfSkeleton() {
  Column(verticalArrangement = Arrangement.spacedBy(SHELF_TITLE_SPACING)) {
    SkeletonTextLine(
      modifier = Modifier.padding(horizontal = Dp.edge),
      width = SHELF_TITLE_WIDTH,
    )
    Row(
      Modifier
        .horizontalScroll(rememberScrollState(), enabled = false)
        .padding(horizontal = Dp.edge),
      horizontalArrangement = Arrangement.spacedBy(SHELF_TILE_SPACING),
      verticalAlignment = Alignment.Top,
    ) {
      repeat(SKELETON_TILES) { TileSkeleton() }
    }
  }
}

@Composable
private fun TileSkeleton() {
  Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
    SkeletonBlock(Modifier.size(COLLECTION_TILE_SIZE))
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
      SkeletonTextLine(width = TILE_TITLE_WIDTH)
      SkeletonTextLine(width = TILE_SUBTITLE_WIDTH)
    }
  }
}

@Preview(showBackground = true, name = "Sound shelves skeleton")
@Composable
private fun SoundShelvesSkeletonPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      SoundShelvesSkeleton(Modifier.padding(vertical = Dp.rhythm))
    }
  }
}
