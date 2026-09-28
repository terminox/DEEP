package io.appbeyond.freelance.deep.feature.deepsound.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.feature.deepsound.SoundFixtures
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.softPress
import io.appbeyond.freelance.deep.theme.tile

// MARK: - Constants

/** The shelf tile's side — iOS's `tileSize: 150`. */
internal val COLLECTION_TILE_SIZE = 150.dp

/** The artwork's lift — iOS's `shadow(lavenderMist 0.2, radius: 12, y: 8)`. */
private const val ARTWORK_SHADOW_ALPHA = 0.2f
private val ARTWORK_SHADOW_RADIUS = 12.dp
private val ARTWORK_SHADOW_OFFSET_Y = 8.dp

// MARK: - Tile

/**
 * A single artwork tile inside a home shelf: square artwork on a soft lavender
 * lift, the collection's title and a one-line subtitle. Tapping asks the
 * coordinator to open the collection — there is no play button here, the
 * detail is where listening starts.
 *
 * Ported from Deep/Deep/Features/DeepSound/Components/CollectionTile.swift. iOS
 * reads `openCollection` from the environment; a Compose leaf takes the
 * navigation as a lambda instead, so it never knows where it leads.
 *
 * The lift is `Modifier.dropShadow`, as in `frostedCard`: a platform elevation
 * shadow reads as hard grey against the atmosphere.
 */
@Composable
fun CollectionTile(
  collection: SoundCollection,
  onOpen: (SoundCollection) -> Unit,
  modifier: Modifier = Modifier,
  size: Dp = COLLECTION_TILE_SIZE,
) {
  val shape = RoundedCornerShape(Dp.tile)

  Column(
    modifier
      .width(size)
      .softPress()
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        role = Role.Button,
        onClick = { onOpen(collection) },
      ),
    verticalArrangement = Arrangement.spacedBy(8.dp),
  ) {
    ArtworkImage(
      url = collection.imageUrl,
      palette = collection.palette,
      contentDescription = null,
      modifier = Modifier
        .size(size)
        .dropShadow(
          shape = shape,
          shadow = Shadow(
            radius = ARTWORK_SHADOW_RADIUS,
            color = Color.lavenderMist.copy(alpha = ARTWORK_SHADOW_ALPHA),
            offset = DpOffset(0.dp, ARTWORK_SHADOW_OFFSET_Y),
          ),
        )
        .clip(shape),
    )

    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
      Text(
        text = collection.title,
        style = DeepType.bodyMedium,
        color = Color.deepPlum,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.fillMaxWidth(),
      )
      Text(
        text = collection.subtitle,
        style = DeepType.caption,
        color = Color.driftGrey,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.fillMaxWidth(),
      )
    }
  }
}

// MARK: - Preview

@Preview(showBackground = true, name = "Collection tile")
@Composable
private fun CollectionTilePreview() {
  DeepTheme {
    Box(Modifier.background(Color.moonCream).padding(Dp.edge)) {
      CollectionTile(collection = SoundFixtures.oceanDepths, onOpen = {})
    }
  }
}
