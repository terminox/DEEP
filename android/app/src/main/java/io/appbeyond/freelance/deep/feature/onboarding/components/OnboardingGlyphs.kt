package io.appbeyond.freelance.deep.feature.onboarding.components

import androidx.compose.foundation.Canvas
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathBuilder
import androidx.compose.ui.graphics.vector.PathData
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.feature.appshell.DeepIcons
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream

// MARK: - Line glyphs

/**
 * The onboarding flow's glyphs, drawn the way [DeepIcons] draws the tab bar's:
 * stroked paths on a 24dp canvas, 1.5 stroke, round caps and joins, tinted by
 * `Icon` at the call site.
 *
 * iOS reaches for SF Symbols here (`chevron.backward`, `envelope`, `lock`,
 * `eye`, `eye.slash`). The app ships no Material icon set, and DESIGN.md asks
 * for custom rounded line icons anyway — so these are the same shapes, redrawn
 * in the tab bar's hand. The person glyph is [DeepIcons.Person] itself, not a
 * second copy.
 */
internal object OnboardingGlyphs {

  /** `chevron.backward`. */
  val ChevronBack: ImageVector = lineGlyph("OnboardingChevronBack") {
    moveTo(14.5f, 5.5f)
    lineTo(8f, 12f)
    lineTo(14.5f, 18.5f)
  }

  /** `envelope`: a letter, its flap folded to the centre. */
  val Envelope: ImageVector = lineGlyph("OnboardingEnvelope") {
    moveTo(5.5f, 5.75f)
    lineTo(18.5f, 5.75f)
    curveTo(19.6f, 5.75f, 20.25f, 6.4f, 20.25f, 7.5f)
    lineTo(20.25f, 16.5f)
    curveTo(20.25f, 17.6f, 19.6f, 18.25f, 18.5f, 18.25f)
    lineTo(5.5f, 18.25f)
    curveTo(4.4f, 18.25f, 3.75f, 17.6f, 3.75f, 16.5f)
    lineTo(3.75f, 7.5f)
    curveTo(3.75f, 6.4f, 4.4f, 5.75f, 5.5f, 5.75f)
    close()
    moveTo(4.5f, 7f)
    lineTo(12f, 12.75f)
    lineTo(19.5f, 7f)
  }

  /** `lock`: a rounded body under an open-topped shackle. */
  val Lock: ImageVector = lineGlyph("OnboardingLock") {
    moveTo(7f, 10.75f)
    lineTo(17f, 10.75f)
    curveTo(18.1f, 10.75f, 18.75f, 11.4f, 18.75f, 12.5f)
    lineTo(18.75f, 18.5f)
    curveTo(18.75f, 19.6f, 18.1f, 20.25f, 17f, 20.25f)
    lineTo(7f, 20.25f)
    curveTo(5.9f, 20.25f, 5.25f, 19.6f, 5.25f, 18.5f)
    lineTo(5.25f, 12.5f)
    curveTo(5.25f, 11.4f, 5.9f, 10.75f, 7f, 10.75f)
    close()
    moveTo(8.25f, 10.75f)
    lineTo(8.25f, 7.75f)
    curveTo(8.25f, 5.5f, 9.9f, 3.75f, 12f, 3.75f)
    curveTo(14.1f, 3.75f, 15.75f, 5.5f, 15.75f, 7.75f)
    lineTo(15.75f, 10.75f)
  }

  /** `eye`: the almond and its iris. */
  val Eye: ImageVector = lineGlyph("OnboardingEye") {
    eyeOutline()
  }

  /** `eye.slash`: the same eye, struck through. */
  val EyeSlash: ImageVector = lineGlyph("OnboardingEyeSlash") {
    eyeOutline()
    moveTo(4.5f, 4.5f)
    lineTo(19.5f, 19.5f)
  }

  /** The almond (two arcs) and a 3-radius iris at the centre. */
  private fun PathBuilder.eyeOutline() {
    moveTo(2.75f, 12f)
    curveTo(4.9f, 8f, 8.2f, 5.75f, 12f, 5.75f)
    curveTo(15.8f, 5.75f, 19.1f, 8f, 21.25f, 12f)
    curveTo(19.1f, 16f, 15.8f, 18.25f, 12f, 18.25f)
    curveTo(8.2f, 18.25f, 4.9f, 16f, 2.75f, 12f)
    close()
    moveTo(12f, 9f)
    curveTo(13.66f, 9f, 15f, 10.34f, 15f, 12f)
    curveTo(15f, 13.66f, 13.66f, 15f, 12f, 15f)
    curveTo(10.34f, 15f, 9f, 13.66f, 9f, 12f)
    curveTo(9f, 10.34f, 10.34f, 9f, 12f, 9f)
    close()
  }

  private fun lineGlyph(name: String, path: PathBuilder.() -> Unit): ImageVector =
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

// MARK: - Selection marks

/** The mark's diameter — iOS's `.font(.system(size: 22))` check and 22pt ring. */
internal val SELECTION_MARK_SIZE = 22.dp

/** The hollow ring's stroke — iOS's `lineWidth: 1.5`. */
private val RING_STROKE = 1.5.dp

/** The check's stroke, as a fraction of the mark's diameter. */
private const val CHECK_STROKE_FRACTION = 0.09f

/**
 * iOS's `checkmark.circle.fill`: a filled lavender disc with the check knocked
 * out of it in white. Drawn, since there is no SF Symbol to reach for.
 */
@Composable
internal fun FilledCheckMark(modifier: Modifier = Modifier, size: Dp = SELECTION_MARK_SIZE) {
  Canvas(modifier.size(size)) {
    val d = this.size.minDimension
    drawCircle(color = Color.lavenderMist)
    val check = Path().apply {
      moveTo(d * 0.29f, d * 0.52f)
      lineTo(d * 0.44f, d * 0.66f)
      lineTo(d * 0.72f, d * 0.37f)
    }
    drawPath(
      path = check,
      color = Color.White,
      style = Stroke(width = d * CHECK_STROKE_FRACTION, cap = StrokeCap.Round, join = StrokeJoin.Round),
    )
  }
}

/** The not-yet-chosen state: a hollow drift-grey ring, `strokeBorder` style (inset). */
@Composable
internal fun HollowMark(alpha: Float, modifier: Modifier = Modifier, size: Dp = SELECTION_MARK_SIZE) {
  Canvas(modifier.size(size)) {
    val stroke = RING_STROKE.toPx()
    drawCircle(
      color = Color.driftGrey.copy(alpha = alpha),
      radius = this.size.minDimension / 2f - stroke / 2f,
      center = Offset(this.size.width / 2f, this.size.height / 2f),
      style = Stroke(width = stroke),
    )
  }
}

// MARK: - Preview backdrop

/**
 * The host backdrop previews stand on: `AppRoot` keeps one moonCream +
 * [AtmosphereBackground] under every onboarding phase, and leaf screens draw
 * none of their own, so a preview supplies it the way the app does.
 */
@Composable
internal fun OnboardingPreviewBackdrop(content: @Composable () -> Unit) {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      content()
    }
  }
}

@Preview(showBackground = true, name = "Glyphs")
@Composable
private fun OnboardingGlyphsPreview() {
  OnboardingPreviewBackdrop {
    Row(
      modifier = Modifier.padding(Dp.edge),
      horizontalArrangement = Arrangement.spacedBy(16.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      listOf(
        OnboardingGlyphs.ChevronBack,
        DeepIcons.Person,
        OnboardingGlyphs.Envelope,
        OnboardingGlyphs.Lock,
        OnboardingGlyphs.Eye,
        OnboardingGlyphs.EyeSlash,
      ).forEach { Icon(it, contentDescription = null, tint = Color.deepPlum) }
      FilledCheckMark()
      HollowMark(alpha = 0.5f)
    }
  }
}
