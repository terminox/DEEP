package io.appbeyond.freelance.deep.feature.globalpause.model

import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId

/**
 * The Global Pause card's resting line, "Today · 8:10 AM", as data: which day
 * word, and the wall-clock time to print after it. The app renders it through
 * its own string resources and the locale's time format.
 *
 * Read in the **member's own timezone**, not the pause's. The schedule payload
 * carries a `timezone`, but that is the zone the sessions are written in and
 * the day the awards key on — not the zone anyone reads the card in. With
 * sessions placed across the day so that people outside Asia get one at a sane
 * local hour, a Bangkok wall clock would make exactly those sessions
 * unreadable to exactly the people they were added for. No zone is ever named:
 * `Asia/Bangkok` localizes to "Indochina Time" or "GMT+7", both worse copy
 * than none. Two members in different zones seeing different numbers for the
 * same instant is correct.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Session/PauseScheduleLine.swift.
 * Pure, and free of any clock of its own, so the day word can be tested.
 */
data class PauseScheduleLine(val day: Day, val time: LocalTime) {

  enum class Day { Today, Tomorrow }

  companion object {
    /**
     * The server never resolves further ahead than the next calendar day, so
     * two words cover it. (A late Bangkok session read from a UTC+14 device can
     * technically land the day after tomorrow; reading "Tomorrow" there is a
     * rounding error, not a third case anyone will meet.)
     *
     * Day keys are compared as ISO dates, never through a localized calendar —
     * a Thai phone's Buddhist calendar must not shift them.
     */
    fun of(target: Instant, now: Instant, zone: ZoneId): PauseScheduleLine {
      val targetLocal = target.atZone(zone)
      val sameDay = targetLocal.toLocalDate() == now.atZone(zone).toLocalDate()
      return PauseScheduleLine(
        day = if (sameDay) Day.Today else Day.Tomorrow,
        time = targetLocal.toLocalTime(),
      )
    }
  }
}
