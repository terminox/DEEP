package io.appbeyond.freelance.deep.feature.deepsound

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathBuilder
import androidx.compose.ui.graphics.vector.PathData
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream

/**
 * Deep Sound's shared glyphs — the ones both the collection screens and the
 * player reach for (play, the open bookmark) plus the collection screens' own
 * (shuffle, the struck bookmark, the two chevrons). [PlayerIcons] carries the
 * rest of the transport. Drawn in the same hand as
 * [io.appbeyond.freelance.deep.feature.appshell.DeepIcons]: paths on a 24dp
 * canvas, 1.5 stroke, round caps and joins, no colour of their own — `Icon`
 * tints them at the call site.
 *
 * iOS reaches for SF Symbols here (`play.fill`, `shuffle`, `bookmark`,
 * `bookmark.slash`, `chevron.left`, `chevron.right`). The app carries no
 * Material icon dependency, and DESIGN.md asks for custom rounded line icons
 * anyway, so each is redrawn rather than borrowed.
 */
object SoundIcons {

  /**
   * `play.fill` — the one solid glyph, as it is in every music player: a
   * 1.5-stroke outline of a triangle reads as a disabled control. Its stroke is
   * the fill's own colour, so it only rounds the corners. Optically nudged
   * right — a centred triangle looks left-heavy.
   */
  val Play: ImageVector = glyph("SoundPlay", filled = true) {
    moveTo(8f, 5.25f)
    lineTo(19f, 12f)
    lineTo(8f, 18.75f)
    close()
  }

  /** Shuffle — two crossing paths, each ending in an arrowhead. */
  val Shuffle: ImageVector = glyph("SoundShuffle") {
    // Top-left to bottom-right.
    moveTo(3.5f, 7f)
    lineTo(6.5f, 7f)
    curveTo(11f, 7f, 12.5f, 17f, 17f, 17f)
    lineTo(20.5f, 17f)
    // Bottom-left to top-right.
    moveTo(3.5f, 17f)
    lineTo(6.5f, 17f)
    curveTo(11f, 17f, 12.5f, 7f, 17f, 7f)
    lineTo(20.5f, 7f)
    // Arrowheads.
    moveTo(18f, 4.5f)
    lineTo(20.5f, 7f)
    lineTo(18f, 9.5f)
    moveTo(18f, 14.5f)
    lineTo(20.5f, 17f)
    lineTo(18f, 19.5f)
  }

  /**
   * `bookmark` — a sound not yet saved. [PlayerIcons.BookmarkFilled] fills
   * exactly this ribbon, so the two crossfade without a shift.
   */
  val Bookmark: ImageVector = glyph("SoundBookmark") { ribbon() }

  /** `bookmark.slash` — "Remove from playlist": the same ribbon, struck through. */
  val BookmarkSlash: ImageVector = glyph("SoundBookmarkSlash") {
    ribbon()
    moveTo(4f, 4f)
    lineTo(20f, 20f)
  }

  /** `chevron.left` — the pushed detail's back control. */
  val ChevronBack: ImageVector = glyph("SoundChevronBack") {
    moveTo(14.5f, 6f)
    lineTo(8.5f, 12f)
    lineTo(14.5f, 18f)
  }

  /** `chevron.right` — the Breathe card's "go", which says go rather than play. */
  val ChevronForward: ImageVector = glyph("SoundChevronForward") {
    moveTo(9.5f, 6f)
    lineTo(15.5f, 12f)
    lineTo(9.5f, 18f)
  }

  /** The bookmark ribbon, shared point for point with [PlayerIcons.BookmarkFilled]. */
  private fun PathBuilder.ribbon() {
    moveTo(8f, 4f)
    lineTo(16f, 4f)
    curveTo(16.8f, 4f, 17.5f, 4.7f, 17.5f, 5.5f)
    lineTo(17.5f, 20f)
    lineTo(12f, 16f)
    lineTo(6.5f, 20f)
    lineTo(6.5f, 5.5f)
    curveTo(6.5f, 4.7f, 7.2f, 4f, 8f, 4f)
    close()
  }

  private fun glyph(
    name: String,
    filled: Boolean = false,
    path: PathBuilder.() -> Unit,
  ): ImageVector =
    ImageVector.Builder(
      name = name,
      defaultWidth = 24.dp,
      defaultHeight = 24.dp,
      viewportWidth = 24f,
      viewportHeight = 24f,
    ).addPath(
      pathData = PathData(path),
      // Black stands in for either paint; the Icon tint replaces it at the call site.
      fill = if (filled) SolidColor(Color.Black) else null,
      stroke = SolidColor(Color.Black),
      strokeLineWidth = STROKE_WIDTH,
      strokeLineCap = StrokeCap.Round,
      strokeLineJoin = StrokeJoin.Round,
    ).build()
}

/** DESIGN.md's line weight — "1.5pt stroke, soft terminals". */
private const val STROKE_WIDTH = 1.5f

// MARK: - Preview

@Preview(showBackground = true, name = "Sound icons")
@Composable
private fun SoundIconsPreview() {
  Row(
    Modifier
      .background(Color.moonCream)
      .padding(Dp.edge),
    horizontalArrangement = Arrangement.spacedBy(16.dp),
  ) {
    listOf(
      SoundIcons.Play,
      SoundIcons.Shuffle,
      SoundIcons.Bookmark,
      SoundIcons.BookmarkSlash,
      SoundIcons.ChevronBack,
      SoundIcons.ChevronForward,
    ).forEach { icon ->
      Icon(icon, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(28.dp))
    }
  }
}
