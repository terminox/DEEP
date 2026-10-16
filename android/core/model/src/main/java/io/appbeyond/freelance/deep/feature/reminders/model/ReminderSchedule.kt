package io.appbeyond.freelance.deep.feature.reminders.model

import java.time.Duration
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZonedDateTime

/**
 * When the daily reminder should fire, as pure arithmetic.
 *
 * iOS caps an app at 64 pending notification requests, and a *repeating*
 * calendar trigger — one request, forever — cannot skip a single occurrence.
 * Skipping matters here: a day whose practice is already done should pass in
 * silence, because being reminded to do what you have already done is exactly
 * the "you are behind" register `DESIGN.md` rules out. So the schedule is a
 * window of individually dated requests, rebuilt every time the app comes
 * forward. Eight weeks of them sits comfortably under the cap, and someone
 * who hasn't opened DEEP in eight weeks has a bigger gap than a notification
 * closes.
 *
 * Ported from Deep/Deep/Features/Reminders/Models/ReminderSchedule.swift,
 * date arithmetic unchanged. Android has no 64-pending-request cap, and its
 * scheduling layer (`AlarmReminderScheduler` in `:app`) arms only the first
 * occurrence and re-arms from here each time one fires; the window is kept
 * whole so the store and its tests read exactly as iOS's do.
 *
 * **A spring-forward gap skips the day,** as iOS's guarded
 * `calendar.date(bySettingHour:)` does: a member who chose 02:30 gets nothing
 * on the night 02:00 jumps to 03:00, rather than a nudge at 03:30 they never
 * asked for. `ZonedDateTime.withHour` would resolve forward by the gap, so the
 * wall time is checked against the zone's rules first. A fall-back overlap
 * keeps the earlier of the two instants, as `ZonedDateTime` does by default.
 *
 * Kept free of any notification API on purpose: the date maths is the part
 * worth testing, and it tests as a pure function (the `PracticeMath`
 * pattern). `now` and every occurrence are [ZonedDateTime] rather than a bare
 * instant, so the day-boundary and hour/minute maths run in the reminder's
 * own zone and stay correct across a DST transition inside the window.
 */
object ReminderSchedule {
  /** How many future occurrences to keep queued. */
  const val horizon = 56

  /**
   * How late the system may deliver an occurrence: Android arms the nudge as
   * an inexact alarm in a window this long from the chosen minute (the
   * shortest window `setWindow` honours). An occurrence inside it may not
   * have fired yet; see `ReminderStore.reschedule`.
   */
  val deliveryWindow: Duration = Duration.ofMinutes(10)

  /**
   * The next [limit] firing times after [after].
   *
   * @param goalMetToday today's practice is already complete, so today's
   *   occurrence is dropped. Only today can be known this way; every later
   *   day is scheduled and withdrawn later if it turns out the same.
   */
  fun occurrences(
    after: ZonedDateTime,
    reminder: DailyReminder,
    goalMetToday: Boolean,
    limit: Int = horizon,
  ): List<ZonedDateTime> {
    if (!reminder.isEnabled || limit <= 0) return emptyList()

    val found = mutableListOf<ZonedDateTime>()
    var dayOffset = 0
    // A bounded walk rather than an unbounded loop: an unrepresentable wall
    // time must never spin here.
    while (found.size < limit && dayOffset < limit + 7) {
      val day = after.toLocalDate().plusDays(dayOffset.toLong())
      dayOffset++
      val wallTime = LocalDateTime.of(day, LocalTime.of(reminder.hour, reminder.minute))
      // No valid offset means the clock jumps over this wall time today.
      if (after.zone.rules.getValidOffsets(wallTime).isEmpty()) continue
      val fires = ZonedDateTime.of(wallTime, after.zone)
      // Strictly after `now`, so rescheduling at 21:00:30 doesn't re-queue
      // the 21:00 that just fired.
      if (!fires.isAfter(after)) continue
      if (goalMetToday && fires.toLocalDate() == after.toLocalDate()) continue
      found.add(fires)
    }
    return found
  }
}
