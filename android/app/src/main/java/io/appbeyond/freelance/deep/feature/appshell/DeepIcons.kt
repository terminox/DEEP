package io.appbeyond.freelance.deep.feature.appshell

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathBuilder
import androidx.compose.ui.graphics.vector.PathData
import androidx.compose.ui.unit.dp

/**
 * The tab bar's five glyphs, drawn rather than borrowed.
 *
 * iOS uses SF Symbols. Android's stock equivalent is Material's icon set, and
 * DESIGN.md rules both out for this surface: *"Custom rounded line icons, 1.5pt
 * stroke, soft terminals."* A Material glyph in the tab bar is the fastest way to
 * make Deep look like a different, cheaper product, and the bar frames every
 * screen in the app.
 *
 * So each is a stroked path on a 24dp canvas at 1.5 stroke with round caps and
 * joins. They carry no colour of their own — `Icon` tints them at the call site,
 * which is what lets the bar dim an unselected tab.
 */
object DeepIcons {

  /** Global Pause. A globe: the world, which is the tab's whole subject. */
  val Globe: ImageVector = lineIcon("DeepGlobe") {
    // Outer sphere, r = 9 at centre, as four cubics (k = r * 0.5523).
    moveTo(12f, 3f)
    curveTo(16.97f, 3f, 21f, 7.03f, 21f, 12f)
    curveTo(21f, 16.97f, 16.97f, 21f, 12f, 21f)
    curveTo(7.03f, 21f, 3f, 16.97f, 3f, 12f)
    curveTo(3f, 7.03f, 7.03f, 3f, 12f, 3f)
    close()
    // The equator.
    moveTo(3f, 12f)
    lineTo(21f, 12f)
    // Two meridians, so the sphere reads as a sphere and not a target.
    moveTo(12f, 3f)
    curveTo(7.5f, 7f, 7.5f, 17f, 12f, 21f)
    moveTo(12f, 3f)
    curveTo(16.5f, 7f, 16.5f, 17f, 12f, 21f)
  }

  /** Deep Sound. A waveform, symmetrical so it reads as a breath, not a level meter. */
  val Waveform: ImageVector = lineIcon("DeepWaveform") {
    moveTo(3.5f, 10f); lineTo(3.5f, 14f)
    moveTo(7.75f, 7f); lineTo(7.75f, 17f)
    moveTo(12f, 4.5f); lineTo(12f, 19.5f)
    moveTo(16.25f, 7f); lineTo(16.25f, 17f)
    moveTo(20.5f, 10f); lineTo(20.5f, 14f)
  }

  /** Mind Garden. A leaf with its midrib. */
  val Leaf: ImageVector = lineIcon("DeepLeaf") {
    moveTo(12f, 21f)
    curveTo(6f, 16.5f, 6f, 8f, 12f, 3f)
    curveTo(18f, 8f, 18f, 16.5f, 12f, 21f)
    close()
    moveTo(12f, 21f)
    lineTo(12f, 3f)
  }

  /** Compassion Portfolio. A heart, open rather than filled. */
  val Heart: ImageVector = lineIcon("DeepHeart") {
    moveTo(12f, 20f)
    curveTo(12f, 20f, 3.75f, 14.5f, 3.75f, 9f)
    curveTo(3.75f, 6.1f, 6.1f, 3.75f, 9f, 3.75f)
    curveTo(10.7f, 3.75f, 12f, 4.7f, 12f, 6.3f)
    curveTo(12f, 4.7f, 13.3f, 3.75f, 15f, 3.75f)
    curveTo(17.9f, 3.75f, 20.25f, 6.1f, 20.25f, 9f)
    curveTo(20.25f, 14.5f, 12f, 20f, 12f, 20f)
    close()
  }

  /** You. A person, shoulders left open so the shape stays soft. */
  val Person: ImageVector = lineIcon("DeepPerson") {
    // Head, r = 3.5 at (12, 8).
    moveTo(12f, 4.5f)
    curveTo(13.93f, 4.5f, 15.5f, 6.07f, 15.5f, 8f)
    curveTo(15.5f, 9.93f, 13.93f, 11.5f, 12f, 11.5f)
    curveTo(10.07f, 11.5f, 8.5f, 9.93f, 8.5f, 8f)
    curveTo(8.5f, 6.07f, 10.07f, 4.5f, 12f, 4.5f)
    close()
    // Shoulders.
    moveTo(4.75f, 20f)
    curveTo(4.75f, 16.2f, 8f, 14f, 12f, 14f)
    curveTo(16f, 14f, 19.25f, 16.2f, 19.25f, 20f)
  }

  private fun lineIcon(name: String, path: PathBuilder.() -> Unit): ImageVector =
    ImageVector.Builder(
      name = name,
      defaultWidth = 24.dp,
      defaultHeight = 24.dp,
      viewportWidth = 24f,
      viewportHeight = 24f,
    ).addPath(
      pathData = PathData(path),
      fill = null,
      stroke = SolidColor(Color.Black), // replaced by the Icon tint at the call site
      strokeLineWidth = 1.5f,
      strokeLineCap = StrokeCap.Round,
      strokeLineJoin = StrokeJoin.Round,
    ).build()
}
