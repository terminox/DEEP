package io.appbeyond.freelance.deep.feature.reminders.model

import java.time.LocalDate

/**
 * Which of the reminder's lines a given day reads.
 *
 * Rotated one per day the way `GardenGreeting` rotates its quotes, so weeks of
 * nudges don't read as the same sentence repeating. The voice follows
 * `DESIGN.md`: an invitation, never a demand — nothing says you missed
 * anything, owe anything, or broke anything.
 *
 * Ported from the rotation in Deep/Deep/Features/Reminders/Models/ReminderCopy.swift.
 * The seven title/body pairs themselves are string resources in `:app`
 * (`reminder_copy_title` / `reminder_copy_body` arrays), resolved in the
 * member's chosen language when the notification is posted; this owns only
 * the deterministic pick, so it can be tested.
 */
object ReminderCopy {

  /** How many title/body pairs the rotation cycles through. */
  const val poolSize = 7

  /**
   * The line for [day] — deterministic, so a reminder reads the same however
   * often the schedule is rebuilt, and seven consecutive days use all seven.
   * Counted from the epoch day rather than iOS's day-of-era ordinal: only the
   * rotation has to match, not which line a given date lands on.
   */
  fun indexFor(day: LocalDate, size: Int = poolSize): Int = Math.floorMod(day.toEpochDay(), size.toLong()).toInt()
}
