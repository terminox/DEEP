package io.appbeyond.freelance.deep.feature.deepsound

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
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

// MARK: - Constants

/** Circle-to-cubic control factor: 4/3 * tan(π/8). */
private const val CIRCLE_K = 0.5523f

/** DESIGN.md's line weight — the stroke every Deep glyph is drawn at. */
private const val LINE_WIDTH = 1.5f

/**
 * The stroke laid over a solid glyph's own outline. Same colour as the fill, so
 * it adds no edge — it only rounds the corners, the way SF Symbols' `.fill`
 * variants have no sharp points.
 */
private const val SOFTENING_WIDTH = 1.5f

/** The list glyph's bullets. */
private const val BULLET_RADIUS = 1.15f

/**
 * The player's glyphs — transport, volume, lyrics and the playlist bookmark —
 * drawn in the same hand as [io.appbeyond.freelance.deep.feature.appshell.DeepIcons]
 * and [io.appbeyond.freelance.deep.feature.profile.ProfileIcons].
 *
 * iOS reaches for SF Symbols (`play.fill`, `pause.fill`, `forward.fill`,
 * `backward.fill`, `speaker.fill`, `speaker.wave.3.fill`, `list.bullet`,
 * `bookmark`, `bookmark.fill`) in `MiniPlayerBar.swift`, `NowPlayingView.swift`
 * and `SaveTrackButton.swift`. They are shared with the rest of Deep Sound —
 * one play triangle and one ribbon across the feature; [SoundIcons] carries
 * only what this set doesn't (shuffle, the struck-through bookmark, chevrons). The transport set is *solid* on iOS, as it is in
 * every music player, and stays solid here: a 1.5-stroke outline of a play
 * triangle at 44dp reads as a disabled control. So these come in two kinds —
 * solid shapes, softened at the corners by a same-colour stroke, and the
 * house's open line work for the rest. Neither carries a colour of its own;
 * `Icon` tints both at the call site.
 */
object PlayerIcons {

  /** `play.fill`. Optically nudged right — a centred triangle looks left-heavy. */
  val Play: ImageVector = glyph("PlayerPlay") {
    solid {
      moveTo(8f, 5.25f)
      lineTo(19f, 12f)
      lineTo(8f, 18.75f)
      close()
    }
  }

  /** `pause.fill` — two rounded bars. */
  val Pause: ImageVector = glyph("PlayerPause") {
    solid {
      bar(6.75f, 5f, 3.5f, 14f)
      bar(13.75f, 5f, 3.5f, 14f)
    }
  }

  /** `forward.fill` — two triangles running right. Skips to the next sound. */
  val Next: ImageVector = glyph("PlayerNext") {
    solid {
      moveTo(3.5f, 6.25f)
      lineTo(11.75f, 12f)
      lineTo(3.5f, 17.75f)
      close()
      moveTo(12.25f, 6.25f)
      lineTo(20.5f, 12f)
      lineTo(12.25f, 17.75f)
      close()
    }
  }

  /** `backward.fill` — [Next], mirrored. */
  val Previous: ImageVector = glyph("PlayerPrevious") {
    solid {
      moveTo(20.5f, 6.25f)
      lineTo(12.25f, 12f)
      lineTo(20.5f, 17.75f)
      close()
      moveTo(11.75f, 6.25f)
      lineTo(3.5f, 12f)
      lineTo(11.75f, 17.75f)
      close()
    }
  }

  /** `speaker.fill` — the quiet end of the volume slider. */
  val Speaker: ImageVector = glyph("PlayerSpeaker") {
    solid { speakerBody(offsetX = 4f) }
  }

  /** `speaker.wave.3.fill` — the loud end: the same body, three waves out. */
  val SpeakerWave: ImageVector = glyph("PlayerSpeakerWave") {
    solid { speakerBody(offsetX = 0f) }
    line {
      moveTo(12.6f, 9.4f)
      arcTo(3.7f, 3.7f, 0f, isMoreThanHalf = false, isPositiveArc = true, x1 = 12.6f, y1 = 14.6f)
      moveTo(15f, 7.2f)
      arcTo(6.8f, 6.8f, 0f, isMoreThanHalf = false, isPositiveArc = true, x1 = 15f, y1 = 16.8f)
      moveTo(17.4f, 5f)
      arcTo(9.9f, 9.9f, 0f, isMoreThanHalf = false, isPositiveArc = true, x1 = 17.4f, y1 = 19f)
    }
  }

  /** `list.bullet` — the lyrics button. */
  val List: ImageVector = glyph("PlayerList") {
    solid {
      dot(5.5f, 7f)
      dot(5.5f, 12f)
      dot(5.5f, 17f)
    }
    line {
      moveTo(9.5f, 7f); lineTo(19.5f, 7f)
      moveTo(9.5f, 12f); lineTo(19.5f, 12f)
      moveTo(9.5f, 17f); lineTo(19.5f, 17f)
    }
  }

  /** `bookmark` — a sound not yet saved. [SoundIcons.BookmarkSlash] strikes through this ribbon. */
  val Bookmark: ImageVector = glyph("PlayerBookmark") {
    line { bookmark() }
  }

  /** `bookmark.fill` — a sound in the playlist, on the same ribbon so a crossfade fills it in place. */
  val BookmarkFilled: ImageVector = glyph("PlayerBookmarkFilled") {
    solid { bookmark() }
  }

  // MARK: - Shapes

  private fun PathBuilder.speakerBody(offsetX: Float) {
    moveTo(3f + offsetX, 9.5f)
    lineTo(6f + offsetX, 9.5f)
    lineTo(10f + offsetX, 6f)
    lineTo(10f + offsetX, 18f)
    lineTo(6f + offsetX, 14.5f)
    lineTo(3f + offsetX, 14.5f)
    close()
  }

  private fun PathBuilder.bookmark() {
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

  private fun PathBuilder.bar(x: Float, y: Float, width: Float, height: Float) {
    moveTo(x, y)
    lineTo(x + width, y)
    lineTo(x + width, y + height)
    lineTo(x, y + height)
    close()
  }

  private fun PathBuilder.dot(cx: Float, cy: Float) {
    val r = BULLET_RADIUS
    val k = r * CIRCLE_K
    moveTo(cx, cy - r)
    curveTo(cx + k, cy - r, cx + r, cy - k, cx + r, cy)
    curveTo(cx + r, cy + k, cx + k, cy + r, cx, cy + r)
    curveTo(cx - k, cy + r, cx - r, cy + k, cx - r, cy)
    curveTo(cx - r, cy - k, cx - k, cy - r, cx, cy - r)
    close()
  }

  // MARK: - Builder

  /**
   * A glyph's layers, in draw order. Solid and line layers can share one glyph
   * (the speaker's body and its waves), which is why this is a small scope
   * rather than one path — a filled open arc would close into a wedge.
   */
  private class GlyphScope(val builder: ImageVector.Builder) {

    fun solid(path: PathBuilder.() -> Unit) {
      builder.addPath(
        pathData = PathData(path),
        fill = SolidColor(Color.Black), // replaced by the Icon tint at the call site
        stroke = SolidColor(Color.Black),
        strokeLineWidth = SOFTENING_WIDTH,
        strokeLineCap = StrokeCap.Round,
        strokeLineJoin = StrokeJoin.Round,
      )
    }

    fun line(path: PathBuilder.() -> Unit) {
      builder.addPath(
        pathData = PathData(path),
        fill = null,
        stroke = SolidColor(Color.Black),
        strokeLineWidth = LINE_WIDTH,
        strokeLineCap = StrokeCap.Round,
        strokeLineJoin = StrokeJoin.Round,
      )
    }
  }

  private fun glyph(name: String, layers: GlyphScope.() -> Unit): ImageVector {
    val builder = ImageVector.Builder(
      name = name,
      defaultWidth = 24.dp,
      defaultHeight = 24.dp,
      viewportWidth = 24f,
      viewportHeight = 24f,
    )
    GlyphScope(builder).layers()
    return builder.build()
  }
}

// MARK: - Preview

@Preview(showBackground = true, name = "Player icons")
@Composable
private fun PlayerIconsPreview() {
  Box(Modifier.fillMaxSize().background(Color.moonCream).padding(Dp.edge)) {
    Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
      listOf(
        PlayerIcons.Play,
        PlayerIcons.Pause,
        PlayerIcons.Previous,
        PlayerIcons.Next,
        PlayerIcons.Speaker,
        PlayerIcons.SpeakerWave,
        PlayerIcons.List,
        PlayerIcons.Bookmark,
        PlayerIcons.BookmarkFilled,
      ).forEach { Icon(it, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(24.dp)) }
    }
  }
}
