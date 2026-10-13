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
 * terminals) — iOS's `xmark` on the session's close button and
 * `speaker.slash.fill` on the muted ON AIR pill.
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
  }
}
