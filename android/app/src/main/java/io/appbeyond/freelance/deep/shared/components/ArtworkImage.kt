package io.appbeyond.freelance.deep.shared.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import coil3.compose.AsyncImagePainter
import coil3.compose.LocalPlatformContext
import coil3.request.ImageRequest
import coil3.size.Precision
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
 *
 * @param placeholderIcon an optional glyph drawn over the gradient while there
 *   is no photo (no url, still loading, or failed) — iOS's
 *   `placeholderSystemImage`. Hidden once the image lands, so a transparent
 *   image (a garden mascot) never shows it through.
 * @param decodeSize the pixel size to decode the photo for, where its first
 *   layout is no guide — Now Playing's full-bleed photograph, which opens out
 *   of the mini player's 36dp thumbnail and would otherwise decode at that
 *   size. Null decodes for the laid-out size, as every tile does. Never
 *   upscaled past the photo's own pixels. iOS's second, screen-size
 *   `ImageLoader`.
 */
@Composable
fun ArtworkImage(
  url: String?,
  palette: String?,
  modifier: Modifier = Modifier,
  contentDescription: String? = null,
  placeholderIcon: ImageVector? = null,
  decodeSize: IntSize? = null,
) {
  var loaded by remember(url) { mutableStateOf(false) }
  val context = LocalPlatformContext.current
  val model = remember(url, decodeSize, context) {
    if (url == null || decodeSize == null) {
      url
    } else {
      ImageRequest.Builder(context)
        .data(url)
        .size(decodeSize.width, decodeSize.height)
        .precision(Precision.INEXACT)
        .build()
    }
  }

  Box(modifier.background(paletteBrush(palette)), contentAlignment = Alignment.Center) {
    if (placeholderIcon != null && !loaded) {
      Icon(
        imageVector = placeholderIcon,
        contentDescription = null,
        tint = Color.White.copy(alpha = PLACEHOLDER_ALPHA),
        modifier = Modifier.size(PLACEHOLDER_SIZE),
      )
    }
    if (model != null) {
      AsyncImage(
        model = model,
        contentDescription = contentDescription,
        contentScale = ContentScale.Crop,
        onState = { loaded = it is AsyncImagePainter.State.Success },
        modifier = Modifier.fillMaxSize(),
      )
    }
  }
}

/** The placeholder glyph — iOS's white 0.55 `title2` light symbol. */
private const val PLACEHOLDER_ALPHA = 0.55f
private val PLACEHOLDER_SIZE = 22.dp

/**
 * The server's palette names, resolved to pairs from DEEP's own palette.
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
    "mist" -> listOf(Color.softLilac, Color.skyWash)
    "meadow" -> listOf(Color.skyWash, Color.moonCream)
    "ember" -> listOf(Color.peachCloud, Color.softLilac)
    else -> listOf(Color.lavenderMist, Color.softLilac)
  }
  return Brush.linearGradient(stops)
}
