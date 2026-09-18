package io.appbeyond.freelance.deep.shared.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import coil3.compose.AsyncImage
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.peachCloud
import io.appbeyond.freelance.deep.theme.skyWash
import io.appbeyond.freelance.deep.theme.softLilac

/**
 * Collection and category artwork, with a palette gradient standing in.
 *
 * The gradient is not an error state — a collection with no artwork yet is an
 * ordinary thing in the admin, and the server sends `imageUrl: null` for it. So
 * the fallback has to be something the design is happy to show, which is why it
 * is drawn from the palette rather than being a grey box with an icon in it.
 *
 * It is also what paints while a real image loads, so the tile never flashes
 * empty.
 */
@Composable
fun ArtworkImage(
  url: String?,
  palette: String?,
  modifier: Modifier = Modifier,
  contentDescription: String? = null,
) {
  Box(modifier.background(paletteBrush(palette))) {
    if (url != null) {
      AsyncImage(
        model = url,
        contentDescription = contentDescription,
        contentScale = ContentScale.Crop,
        modifier = Modifier.fillMaxSize(),
      )
    }
  }
}

/**
 * The server's palette names, resolved to pairs from Deep's own palette.
 *
 * Single-hue ramps rather than arbitrary two-colour blends: neighbouring tiles
 * sit side by side in a shelf, and two saturated gradients next to each other
 * read as noise. An unknown name falls back to the app's own lavender, never to
 * grey.
 */
private fun paletteBrush(palette: String?): Brush {
  val stops = when (palette?.lowercase()) {
    "tide" -> listOf(Color.skyWash, Color.softLilac)
    "dawn" -> listOf(Color.peachCloud, Color.blushPowder)
    "bloom" -> listOf(Color.blushPowder, Color.softLilac)
    "dusk" -> listOf(Color.softLilac, Color.lavenderMist)
    "meadow" -> listOf(Color.skyWash, Color.moonCream)
    "ember" -> listOf(Color.peachCloud, Color.softLilac)
    else -> listOf(Color.lavenderMist, Color.softLilac)
  }
  return Brush.linearGradient(stops)
}
