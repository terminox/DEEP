package io.appbeyond.freelance.deep.feature.practice.model

import java.time.Clock
import java.time.Duration
import java.time.LocalDate
import java.time.ZoneId

/**
 * Where "today" ends — so a screen that shows today's practice can wake at
 * midnight and re-read it, instead of carrying yesterday's minutes into the
 * new day until something else happens to recompose it.
 *
 * Measured to the next local start of day through [ZoneId] rather than as
 * 24 hours, so a daylight-saving night (23 or 25 hours long, or a zone whose
 * midnight is skipped) still lands on the real boundary.
 */
object DayRollover {

  /** Today's date in [zone], as [clock] tells it. */
  fun today(zone: ZoneId, clock: Clock): LocalDate = LocalDate.now(clock.withZone(zone))

  /** Time left until the next day begins in [zone]. Never zero or negative. */
  fun untilNextDay(zone: ZoneId, clock: Clock): Duration {
    val now = clock.instant()
    val nextStart = today(zone, clock).plusDays(1).atStartOfDay(zone).toInstant()
    return Duration.between(now, nextStart).coerceAtLeast(MINIMUM)
  }

  /** A floor, so a wake scheduled exactly on the boundary never spins. */
  private val MINIMUM: Duration = Duration.ofSeconds(1)

  private fun Duration.coerceAtLeast(floor: Duration): Duration = if (this < floor) floor else this
}
