package io.appbeyond.freelance.deep.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import io.appbeyond.freelance.deep.R

// MARK: - Families

/*
 * The one place Android cannot mirror iOS.
 *
 * Deep/Deep/Theme/DeepTypography.swift ships no font files: it takes its serif
 * from New York and its rounded face from SF Rounded, both Apple system faces
 * reached through Font.Design. Android has neither, and its system serif (Noto
 * Serif) and sans (Roboto) do not carry the same feeling, so the faces DESIGN.md
 * actually names are bundled instead.
 *
 * All three are variable fonts, so one file covers every weight a family needs.
 * Weight is selected through FontVariation rather than by shipping a static file
 * per weight — supported from API 26, which is the floor.
 *
 * Licensing is clean: all three are OFL.
 */

private fun weightVariation(weight: Int) =
  FontVariation.Settings(FontVariation.weight(weight))

/** Serif — the emotional register. Wordmark, hero headlines, affirmations. */
private val Serif = FontFamily(
  Font(
    R.font.cormorant_garamond_variable,
    FontWeight.Light,
    FontStyle.Normal,
    variationSettings = weightVariation(300),
  ),
  Font(
    R.font.cormorant_garamond_italic_variable,
    FontWeight.Light,
    FontStyle.Italic,
    variationSettings = weightVariation(300),
  ),
)

/** Sans — clarity in interface elements. */
private val Sans = FontFamily(
  Font(
    R.font.inter_variable,
    FontWeight.Normal,
    FontStyle.Normal,
    variationSettings = weightVariation(400),
  ),
  Font(
    R.font.inter_variable,
    FontWeight.Medium,
    FontStyle.Normal,
    variationSettings = weightVariation(500),
  ),
)

/**
 * Rounded — the numeral faces.
 *
 * Standing in for SF Rounded, which has no Android equivalent. Nunito is the
 * closest free face with the weight range the three numeral tokens need. This is
 * a judgement call, flagged in ANDROID_ROADMAP.md as open until it has been seen
 * beside the iOS build.
 */
private val Rounded = FontFamily(
  Font(
    R.font.nunito_variable,
    FontWeight.Light,
    FontStyle.Normal,
    variationSettings = weightVariation(300),
  ),
  Font(
    R.font.nunito_variable,
    FontWeight.Medium,
    FontStyle.Normal,
    variationSettings = weightVariation(500),
  ),
)

/**
 * Fixed-width digits, for text that ticks. A proportional "1" is narrower than a
 * "4", so a live timer would jitter sideways.
 */
private const val TABULAR_FIGURES = "tnum"

// MARK: - Type scale

/**
 * The Deep type scale, aligned with DESIGN.md and with
 * Deep/Deep/Theme/DeepTypography.swift.
 *
 * Sizes are the iOS Dynamic Type text styles the tokens are anchored to, at their
 * default sizes. They are declared in sp, so Android's font-size setting scales
 * them the way Dynamic Type scales the originals — no extra work.
 *
 * Every style the app uses originates here. Never declare a font inline.
 */
object DeepType {

  /** Serif italic wordmark — "deep", "Global Pause". */
  val wordmark = TextStyle(
    fontFamily = Serif,
    fontWeight = FontWeight.Light,
    fontStyle = FontStyle.Italic,
    fontSize = 28.sp,
    lineHeight = 34.sp,
    letterSpacing = 0.56.sp, // +2%, so the letters breathe
  )

  /** Serif light — section titles, card titles, affirmations. */
  val displayTitle = TextStyle(
    fontFamily = Serif,
    fontWeight = FontWeight.Light,
    fontSize = 22.sp,
    lineHeight = 28.sp,
    letterSpacing = 0.44.sp,
  )

  /** Sans medium — UI section headers. */
  val sectionTitle = TextStyle(
    fontFamily = Sans,
    fontWeight = FontWeight.Medium,
    fontSize = 17.sp,
    lineHeight = 24.sp,
  )

  /** Body copy. Line height 1.6, taller than typical UI, for a slower read. */
  val body = TextStyle(
    fontFamily = Sans,
    fontWeight = FontWeight.Normal,
    fontSize = 15.sp,
    lineHeight = 24.sp,
  )

  /** Body copy at medium weight — pill labels, emphasised rows. */
  val bodyMedium = TextStyle(
    fontFamily = Sans,
    fontWeight = FontWeight.Medium,
    fontSize = 15.sp,
    lineHeight = 24.sp,
  )

  /** Caption — metadata, schedule lines. */
  val caption = TextStyle(
    fontFamily = Sans,
    fontWeight = FontWeight.Normal,
    fontSize = 13.sp,
    lineHeight = 20.sp,
  )

  /** Micro label — all-caps eyebrows, e.g. HR / MIN / SEC. */
  val micro = TextStyle(
    fontFamily = Sans,
    fontWeight = FontWeight.Medium,
    fontSize = 11.sp,
    lineHeight = 16.sp,
    letterSpacing = 1.4.sp, // breathing room for all-caps
  )

  /** Rounded — countdowns and large counts. */
  val counter = TextStyle(
    fontFamily = Rounded,
    fontWeight = FontWeight.Medium,
    fontSize = 22.sp,
    lineHeight = 28.sp,
  )

  /** Pill copy with ticking digits, e.g. "Live in 13:44". */
  val countdown = TextStyle(
    fontFamily = Sans,
    fontWeight = FontWeight.Medium,
    fontSize = 15.sp,
    lineHeight = 20.sp,
    fontFeatureSettings = TABULAR_FIGURES,
  )

  /** Big participant count. */
  val bigNumber = TextStyle(
    fontFamily = Rounded,
    fontWeight = FontWeight.Medium,
    fontSize = 28.sp,
    lineHeight = 34.sp,
  )

  /**
   * The one numeral a whole screen is about — the Deep Session length being
   * chosen. The scale's largest rung by a distance, which is the point: it stands
   * far above every other token rather than at the next step up.
   */
  val heroNumber = TextStyle(
    fontFamily = Rounded,
    fontWeight = FontWeight.Light,
    fontSize = 96.sp,
    lineHeight = 104.sp,
    fontFeatureSettings = TABULAR_FIGURES,
  )

  /** Serif italic reveal — the tapped country's name over the globe. */
  val revealTitle = TextStyle(
    fontFamily = Serif,
    fontWeight = FontWeight.Light,
    fontStyle = FontStyle.Italic,
    fontSize = 20.sp,
    lineHeight = 26.sp,
  )
}
