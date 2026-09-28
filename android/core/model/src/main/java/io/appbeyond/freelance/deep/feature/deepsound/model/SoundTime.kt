package io.appbeyond.freelance.deep.feature.deepsound.model

import java.util.Locale
import kotlin.math.roundToInt

/**
 * Ported from Deep/Deep/Features/DeepSound/Models/SoundContent.swift's
 * `TimeInterval.clockString` / `.minutesString`.
 *
 * Negative input is guarded to zero — nothing upstream should ever produce a
 * negative duration or elapsed time, but a clock string is exactly the kind
 * of thing that ends up on screen if one slips through.
 */
object SoundTime {
  /** Clock string like "4:05", used by track rows and the scrubber. Rounds
   * [seconds] half-away-from-zero, matching Swift's `TimeInterval.rounded()`. */
  fun clock(seconds: Double): String {
    val total = guard(seconds).roundToInt()
    return String.format(Locale.ROOT, "%d:%02d", total / 60, total % 60)
  }

  /** Human duration in whole minutes, at least 1. The "min" suffix is added
   * by Android string resources, so this returns the bare count. */
  fun minutes(seconds: Double): Int = maxOf(1, (guard(seconds) / 60).roundToInt())

  private fun guard(seconds: Double): Double = if (seconds < 0) 0.0 else seconds
}
