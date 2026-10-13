package io.appbeyond.freelance.deep.shared.localization

import android.icu.text.CompactDecimalFormat
import android.icu.text.NumberFormat
import android.icu.text.RelativeDateTimeFormatter
import android.icu.util.ULocale
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.platform.LocalConfiguration
import java.time.LocalTime
import java.time.chrono.IsoChronology
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.format.FormatStyle
import java.util.Locale

/**
 * Figures, shares, times and relative dates in the language DEEP reads in —
 * iOS's `.formatted(... .locale(.app))` family.
 *
 * Every formatter takes the locale explicitly, read from the composition's
 * configuration ([rememberAppLocale]), so a screen formats in the language it
 * is showing even below API 33, where the per-app language is applied to the
 * activity's configuration rather than to `Locale.getDefault()`.
 *
 * ICU (`android.icu`, API 24+) rather than `java.text` for the compact and
 * relative forms, which `java.text` lacks: "18.5K", "1.8 หมื่น", "2 days ago".
 * Dates never pass through here as day keys — those stay Gregorian and
 * `en_US_POSIX` (see the Thai Buddhist-calendar note in `:core:model`); a
 * relative date has no year to shift.
 */
object AppFormat {

  /** A whole number with grouping — "2,450". */
  fun number(value: Int, locale: Locale): String = NumberFormat.getIntegerInstance(locale).format(value.toLong())

  /** A compact count — "18.5K" / "1.8 หมื่น" (iOS `.notation(.compactName)`). */
  fun compact(value: Int, locale: Locale): String =
    CompactDecimalFormat.getInstance(ULocale.forLocale(locale), CompactDecimalFormat.CompactStyle.SHORT)
      .format(value.toLong())

  /** A share as a whole percent — "22%" (iOS `.percent.precision(.fractionLength(0))`). */
  fun percent(share: Float, locale: Locale): String =
    NumberFormat.getPercentInstance(locale).apply { maximumFractionDigits = 0 }.format(share.toDouble())

  /** A clock face in the locale's own convention — "9:00 PM" in US English, "21:00" in Thai. */
  fun time(hour: Int, minute: Int, locale: Locale): String =
    DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale).format(LocalTime.of(hour, minute))

  /** Whether the locale reads a clock on 24 hours, for the time picker's dial. */
  fun uses24Hour(locale: Locale): Boolean {
    val pattern = DateTimeFormatterBuilder.getLocalizedDateTimePattern(
      null,
      FormatStyle.SHORT,
      IsoChronology.INSTANCE,
      locale,
    )
    return 'H' in pattern || 'k' in pattern
  }

  /**
   * How long ago, named — "yesterday", "6 days ago", "last week", "2 weeks
   * ago" — as iOS's `.relative(presentation: .named)` picks the largest whole
   * unit.
   */
  fun daysAgo(days: Int, locale: Locale): String {
    val formatter = RelativeDateTimeFormatter.getInstance(ULocale.forLocale(locale))
    return when {
      days <= 0 -> formatter.format(RelativeDateTimeFormatter.Direction.THIS, RelativeDateTimeFormatter.AbsoluteUnit.DAY)
      days == 1 -> formatter.format(RelativeDateTimeFormatter.Direction.LAST, RelativeDateTimeFormatter.AbsoluteUnit.DAY)
      days < DAYS_PER_WEEK -> formatter.format(
        days.toDouble(),
        RelativeDateTimeFormatter.Direction.LAST,
        RelativeDateTimeFormatter.RelativeUnit.DAYS,
      )
      days < 2 * DAYS_PER_WEEK -> formatter.format(
        RelativeDateTimeFormatter.Direction.LAST,
        RelativeDateTimeFormatter.AbsoluteUnit.WEEK,
      )
      else -> formatter.format(
        (days / DAYS_PER_WEEK).toDouble(),
        RelativeDateTimeFormatter.Direction.LAST,
        RelativeDateTimeFormatter.RelativeUnit.WEEKS,
      )
    }
  }

  private const val DAYS_PER_WEEK = 7
}

/** The locale this composition is showing — the app's chosen language. */
@Composable
@ReadOnlyComposable
fun rememberAppLocale(): Locale =
  LocalConfiguration.current.locales.get(0) ?: Locale.forLanguageTag(AppLanguage.English.localeIdentifier)
