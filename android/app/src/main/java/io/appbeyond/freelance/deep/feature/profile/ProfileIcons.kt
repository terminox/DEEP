package io.appbeyond.freelance.deep.feature.profile

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

/** Circle-to-cubic control factor: 4/3 * tan(π/8). */
private const val CIRCLE_K = 0.5523f

/**
 * The glyphs the You tab and Settings need, drawn in the same hand as
 * [io.appbeyond.freelance.deep.feature.appshell.DeepIcons].
 *
 * iOS reaches for SF Symbols (`bell`, `creditcard`, `arrow.clockwise`,
 * `rectangle.portrait.and.arrow.right`, `trash`, `sparkles`, `chevron.*`).
 * Material's set is off-limits for the same reason the tab bar draws its own —
 * DESIGN.md asks for rounded 1.5-stroke line icons with soft terminals — and
 * the extended Material icons artifact is not a dependency here anyway. Each is
 * a stroked path on a 24dp canvas, untinted, so `Icon` colours it at the call
 * site.
 *
 * The builder is repeated rather than shared because `DeepIcons.lineIcon` is
 * private to the app shell; hoist both into `shared/` if a third feature needs
 * glyphs.
 */
object ProfileIcons {

  /** Daily reminder. */
  val Bell: ImageVector = lineIcon("ProfileBell") {
    moveTo(6f, 16.5f)
    lineTo(6f, 10.5f)
    curveTo(6f, 7.2f, 8.7f, 4.5f, 12f, 4.5f)
    curveTo(15.3f, 4.5f, 18f, 7.2f, 18f, 10.5f)
    lineTo(18f, 16.5f)
    lineTo(19.5f, 18f)
    lineTo(4.5f, 18f)
    close()
    moveTo(10f, 20.5f)
    curveTo(10.5f, 21.2f, 11.2f, 21.5f, 12f, 21.5f)
    curveTo(12.8f, 21.5f, 13.5f, 21.2f, 14f, 20.5f)
  }

  /** Manage subscription. */
  val CreditCard: ImageVector = lineIcon("ProfileCreditCard") {
    moveTo(5f, 6f)
    lineTo(19f, 6f)
    curveTo(20.1f, 6f, 21f, 6.9f, 21f, 8f)
    lineTo(21f, 16f)
    curveTo(21f, 17.1f, 20.1f, 18f, 19f, 18f)
    lineTo(5f, 18f)
    curveTo(3.9f, 18f, 3f, 17.1f, 3f, 16f)
    lineTo(3f, 8f)
    curveTo(3f, 6.9f, 3.9f, 6f, 5f, 6f)
    close()
    moveTo(3f, 10f)
    lineTo(21f, 10f)
    moveTo(6.5f, 14.5f)
    lineTo(9.5f, 14.5f)
  }

  /** Restore purchases — an open circle running clockwise into its own arrowhead. */
  val ArrowClockwise: ImageVector = lineIcon("ProfileArrowClockwise") {
    moveTo(12f, 5.5f)
    arcTo(7f, 7f, 0f, isMoreThanHalf = true, isPositiveArc = true, x1 = 5.94f, y1 = 9f)
    moveTo(6.46f, 11.95f)
    lineTo(5.94f, 9f)
    lineTo(3.12f, 10.03f)
  }

  /** Log out — a doorway with the arrow leaving through it. */
  val LogOut: ImageVector = lineIcon("ProfileLogOut") {
    moveTo(10f, 4.5f)
    lineTo(6f, 4.5f)
    curveTo(5.2f, 4.5f, 4.5f, 5.2f, 4.5f, 6f)
    lineTo(4.5f, 18f)
    curveTo(4.5f, 18.8f, 5.2f, 19.5f, 6f, 19.5f)
    lineTo(10f, 19.5f)
    moveTo(10f, 12f)
    lineTo(20f, 12f)
    moveTo(16.5f, 8.5f)
    lineTo(20f, 12f)
    lineTo(16.5f, 15.5f)
  }

  /** Delete account. */
  val Trash: ImageVector = lineIcon("ProfileTrash") {
    moveTo(4f, 6.5f)
    lineTo(20f, 6.5f)
    moveTo(9.5f, 6.5f)
    lineTo(9.5f, 4.75f)
    curveTo(9.5f, 4.3f, 9.8f, 4f, 10.25f, 4f)
    lineTo(13.75f, 4f)
    curveTo(14.2f, 4f, 14.5f, 4.3f, 14.5f, 4.75f)
    lineTo(14.5f, 6.5f)
    moveTo(6f, 6.5f)
    lineTo(7f, 19f)
    curveTo(7.1f, 19.8f, 7.7f, 20.5f, 8.5f, 20.5f)
    lineTo(15.5f, 20.5f)
    curveTo(16.3f, 20.5f, 16.9f, 19.8f, 17f, 19f)
    lineTo(18f, 6.5f)
    moveTo(10f, 10f)
    lineTo(10f, 17f)
    moveTo(14f, 10f)
    lineTo(14f, 17f)
  }

  /** The plan chip's mark — one large four-point star and a small one. */
  val Sparkles: ImageVector = lineIcon("ProfileSparkles") {
    moveTo(10f, 6f)
    curveTo(10.6f, 10.4f, 12.6f, 12.4f, 17f, 13f)
    curveTo(12.6f, 13.6f, 10.6f, 15.6f, 10f, 20f)
    curveTo(9.4f, 15.6f, 7.4f, 13.6f, 3f, 13f)
    curveTo(7.4f, 12.4f, 9.4f, 10.4f, 10f, 6f)
    close()
    moveTo(18f, 3f)
    curveTo(18.2f, 4.6f, 18.9f, 5.3f, 20.5f, 5.5f)
    curveTo(18.9f, 5.7f, 18.2f, 6.4f, 18f, 8f)
    curveTo(17.8f, 6.4f, 17.1f, 5.7f, 15.5f, 5.5f)
    curveTo(17.1f, 5.3f, 17.8f, 4.6f, 18f, 3f)
    close()
  }

  /**
   * Settings. Sliders rather than a gear: a gear drawn in this light a stroke
   * reads as a sun, and a sun already means sunlight in the garden.
   */
  val Sliders: ImageVector = lineIcon("ProfileSliders") {
    moveTo(4f, 7f); lineTo(7.25f, 7f)
    circle(9f, 7f, 1.75f)
    moveTo(10.75f, 7f); lineTo(20f, 7f)
    moveTo(4f, 12f); lineTo(13.25f, 12f)
    circle(15f, 12f, 1.75f)
    moveTo(16.75f, 12f); lineTo(20f, 12f)
    moveTo(4f, 17f); lineTo(5.25f, 17f)
    circle(7f, 17f, 1.75f)
    moveTo(8.75f, 17f); lineTo(20f, 17f)
  }

  val ChevronRight: ImageVector = lineIcon("ProfileChevronRight") {
    moveTo(9.5f, 6f)
    lineTo(15.5f, 12f)
    lineTo(9.5f, 18f)
  }

  val ChevronLeft: ImageVector = lineIcon("ProfileChevronLeft") {
    moveTo(14.5f, 6f)
    lineTo(8.5f, 12f)
    lineTo(14.5f, 18f)
  }

  private fun PathBuilder.circle(cx: Float, cy: Float, r: Float) {
    val k = r * CIRCLE_K
    moveTo(cx, cy - r)
    curveTo(cx + k, cy - r, cx + r, cy - k, cx + r, cy)
    curveTo(cx + r, cy + k, cx + k, cy + r, cx, cy + r)
    curveTo(cx - k, cy + r, cx - r, cy + k, cx - r, cy)
    curveTo(cx - r, cy - k, cx - k, cy - r, cx, cy - r)
    close()
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

@Preview(showBackground = true, name = "Profile icons")
@Composable
private fun ProfileIconsPreview() {
  Box(Modifier.fillMaxSize().background(Color.moonCream).padding(Dp.edge)) {
    Row(horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.CenterVertically) {
      listOf(
        ProfileIcons.Bell,
        ProfileIcons.CreditCard,
        ProfileIcons.ArrowClockwise,
        ProfileIcons.LogOut,
        ProfileIcons.Trash,
        ProfileIcons.Sparkles,
        ProfileIcons.Sliders,
        ProfileIcons.ChevronLeft,
      ).forEach { Icon(it, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(24.dp)) }
    }
  }
}
