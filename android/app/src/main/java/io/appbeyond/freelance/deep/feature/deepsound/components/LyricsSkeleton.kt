package io.appbeyond.freelance.deep.feature.deepsound.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.shared.components.SkeletonTextLine
import io.appbeyond.freelance.deep.shared.components.skeletonBreath
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream

private const val LINE_COUNT = 12
private val LINE_SPACING = 12.dp

/** A paragraph's ragged edge: two full lines, then a long and a short one. `null` fills. */
private val LINE_WIDTHS: List<Dp?> = listOf(null, null, 300.dp, 190.dp)

/**
 * A breathing skeleton mirroring a paragraph of lyrics, shown in the lyrics
 * sheet while a track's lyrics are fetched.
 *
 * Ported from Deep/Deep/Features/DeepSound/Components/LyricsSkeleton.swift.
 */
@Composable
fun LyricsSkeleton(modifier: Modifier = Modifier) {
  Column(
    modifier
      .fillMaxWidth()
      .skeletonBreath(),
    verticalArrangement = Arrangement.spacedBy(LINE_SPACING),
  ) {
    repeat(LINE_COUNT) { index ->
      SkeletonTextLine(width = LINE_WIDTHS[index % LINE_WIDTHS.size])
    }
  }
}

@Preview(showBackground = true, name = "Lyrics skeleton")
@Composable
private fun LyricsSkeletonPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      LyricsSkeleton(Modifier.padding(Dp.edge))
    }
  }
}
