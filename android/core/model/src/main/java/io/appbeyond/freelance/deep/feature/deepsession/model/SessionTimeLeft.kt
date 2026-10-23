package io.appbeyond.freelance.deep.feature.deepsession.model

import kotlin.math.roundToInt
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/**
 * How much practice is still ahead, coarse on purpose — a ten-minute session
 * counted in rounds reads as a tally to get through.
 *
 * Ported from `DeepSessionView.remainingLine` in
 * Deep/Deep/Features/DeepSession/Screens/DeepSessionView.swift. The buckets are
 * the iOS ones exactly; only the copy stays at the UI edge, for the reason
 * [DeepSession] keeps its title as a plain string.
 */
sealed interface SessionTimeLeft {
  /** Under half a minute to go. */
  data object AlmostThere : SessionTimeLeft

  /** Half a minute to a minute and a half. */
  data object AboutAMinute : SessionTimeLeft

  /** Anything longer, to the nearest whole minute. */
  data class AboutMinutes(val minutes: Int) : SessionTimeLeft

  companion object {
    /**
     * The bucket [remaining] falls in. Swift's `rounded()` rounds half away
     * from zero; [roundToInt] rounds half up, which is the same for a time
     * that is never negative.
     */
    fun of(remaining: Duration): SessionTimeLeft = when {
      remaining < ALMOST_THERE -> AlmostThere
      remaining < ABOUT_A_MINUTE -> AboutAMinute
      else -> AboutMinutes((remaining.inWholeMilliseconds / 60_000.0).roundToInt())
    }

    private val ALMOST_THERE = 30.seconds
    private val ABOUT_A_MINUTE = 90.seconds
  }
}
