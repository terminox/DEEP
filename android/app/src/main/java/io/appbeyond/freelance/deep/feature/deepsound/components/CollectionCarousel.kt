package io.appbeyond.freelance.deep.feature.deepsound.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.store.SoundLibraryFixtures
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm

/** Title-to-row gap — iOS's `VStack(spacing: 14)`. */
internal val SHELF_TITLE_SPACING = 14.dp

/** Gap between tiles — iOS's `HStack(spacing: 16)`. */
internal val SHELF_TILE_SPACING = 16.dp

/**
 * A titled horizontal row of collection tiles, like Apple Music's home rows.
 *
 * Ported from Deep/Deep/Features/DeepSound/Components/CollectionCarousel.swift.
 * A `LazyRow` rather than iOS's eager `HStack`, with the edge inset as content
 * padding so the first tile lines up with the title and the last scrolls clear
 * of the screen edge.
 *
 * @param onOpenCollection asks the coordinator to open a tapped collection.
 */
@Composable
fun CollectionCarousel(
  title: String,
  collections: List<SoundCollection>,
  onOpenCollection: (SoundCollection) -> Unit,
  modifier: Modifier = Modifier,
  tileSize: Dp = COLLECTION_TILE_SIZE,
) {
  Column(
    modifier.fillMaxWidth(),
    verticalArrangement = Arrangement.spacedBy(SHELF_TITLE_SPACING),
  ) {
    Text(
      text = title,
      style = DeepType.sectionTitle,
      color = Color.deepPlum,
      modifier = Modifier.padding(horizontal = Dp.edge),
    )

    LazyRow(
      horizontalArrangement = Arrangement.spacedBy(SHELF_TILE_SPACING),
      verticalAlignment = Alignment.Top,
      contentPadding = PaddingValues(horizontal = Dp.edge),
    ) {
      items(collections, key = { it.id }) { collection ->
        CollectionTile(collection = collection, onOpen = onOpenCollection, size = tileSize)
      }
    }
  }
}

@Preview(showBackground = true, name = "Collection carousel")
@Composable
private fun CollectionCarouselPreview() {
  DeepTheme {
    Column(
      Modifier
        .background(Color.moonCream)
        .padding(vertical = Dp.rhythm),
    ) {
      CollectionCarousel(
        title = "Calm",
        collections = SoundLibraryFixtures.calm + SoundLibraryFixtures.morning,
        onOpenCollection = {},
      )
    }
  }
}
