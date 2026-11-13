package io.appbeyond.freelance.deep.feature.globalpause.components

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
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.deepPlum

/**
 * Global Pause's own glyphs, drawn in the house hand (1.5 stroke, soft
 * terminals) — iOS's `xmark` on the session's close button,
 * `speaker.slash.fill` on the muted ON AIR pill, and a peace message's
 * `ellipsis` menu with its `flag` and `nosign`.
 */
object GlobalPauseIcons {

  /** `xmark` — the session's one exit. */
  val Close: ImageVector = glyph("PauseClose") {
    line {
      moveTo(7f, 7f); lineTo(17f, 17f)
      moveTo(17f, 7f); lineTo(7f, 17f)
    }
  }

  /** `speaker.slash.fill` — Fuku's set, silenced. */
  val SpeakerSlash: ImageVector = glyph("PauseSpeakerSlash") {
    solid {
      moveTo(4f, 9.5f)
      lineTo(7f, 9.5f)
      lineTo(11f, 6f)
      lineTo(11f, 18f)
      lineTo(7f, 14.5f)
      lineTo(4f, 14.5f)
      close()
    }
    line {
      moveTo(14f, 9f); lineTo(20f, 15f)
      moveTo(20f, 9f); lineTo(14f, 15f)
    }
  }

  /** `ellipsis` — a peace message card's Report and Block menu. */
  val Ellipsis: ImageVector = glyph("PauseEllipsis") {
    solid {
      dot(6f, 12f)
      dot(12f, 12f)
      dot(18f, 12f)
    }
  }

  /** `flag` — Report. */
  val Flag: ImageVector = glyph("PauseFlag") {
    line {
      moveTo(5.5f, 21f); lineTo(5.5f, 4f)
      moveTo(5.5f, 4.5f)
      curveTo(8.5f, 3f, 10.5f, 6f, 13.5f, 5f)
      curveTo(15.5f, 4.3f, 17f, 4f, 18.5f, 4.5f)
      lineTo(18.5f, 13f)
      curveTo(17f, 12.5f, 15.5f, 12.8f, 13.5f, 13.5f)
      curveTo(10.5f, 14.5f, 8.5f, 11.5f, 5.5f, 13f)
    }
  }

  /** `nosign` — Block. */
  val NoSign: ImageVector = glyph("PauseNoSign") {
    line {
      ring(12f, 12f, 8f)
      moveTo(6.35f, 6.35f); lineTo(17.65f, 17.65f)
    }
  }

  private class Layers(val builder: ImageVector.Builder) {
    fun solid(path: PathBuilder.() -> Unit) {
      builder.addPath(
        pathData = PathData(path),
        fill = SolidColor(Color.Black),
        stroke = SolidColor(Color.Black),
        strokeLineWidth = STROKE_WIDTH,
        strokeLineJoin = StrokeJoin.Round,
      )
    }

    fun line(path: PathBuilder.() -> Unit) {
      builder.addPath(
        pathData = PathData(path),
        stroke = SolidColor(Color.Black),
        strokeLineWidth = STROKE_WIDTH,
        strokeLineCap = StrokeCap.Round,
        strokeLineJoin = StrokeJoin.Round,
      )
    }
  }

  private fun PathBuilder.dot(cx: Float, cy: Float) = ring(cx, cy, 1.25f)

  private fun PathBuilder.ring(cx: Float, cy: Float, r: Float) {
    val k = r * 0.5523f
    moveTo(cx, cy - r)
    curveTo(cx + k, cy - r, cx + r, cy - k, cx + r, cy)
    curveTo(cx + r, cy + k, cx + k, cy + r, cx, cy + r)
    curveTo(cx - k, cy + r, cx - r, cy + k, cx - r, cy)
    curveTo(cx - r, cy - k, cx - k, cy - r, cx, cy - r)
    close()
  }

  private fun glyph(name: String, layers: Layers.() -> Unit): ImageVector {
    val builder = ImageVector.Builder(
      name = name,
      defaultWidth = 24.dp,
      defaultHeight = 24.dp,
      viewportWidth = 24f,
      viewportHeight = 24f,
    )
    Layers(builder).layers()
    return builder.build()
  }
}

private const val STROKE_WIDTH = 1.5f

@Preview(showBackground = true, name = "Global Pause glyphs")
@Composable
private fun GlobalPauseIconsPreview() {
  Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
    Icon(GlobalPauseIcons.Close, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(32.dp))
    Icon(GlobalPauseIcons.SpeakerSlash, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(32.dp))
    Icon(GlobalPauseIcons.Ellipsis, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(32.dp))
    Icon(GlobalPauseIcons.Flag, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(32.dp))
    Icon(GlobalPauseIcons.NoSign, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(32.dp))
  }
}
