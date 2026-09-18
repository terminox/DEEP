package io.appbeyond.freelance.deep.feature.reminders.model

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
 * who hasn't opened Deep in eight weeks has a bigger gap than a notification
 * closes.
 *
 * Ported from Deep/Deep/Features/Reminders/Models/ReminderSchedule.swift,
 * date arithmetic unchanged. Android has no 64-pending-request cap the way
 * iOS's `UNUserNotificationCenter` does, so the *scheduling layer* that turns
 * these occurrences into actual system alarms/notifications will differ once
 * reminders ship in week 5 — it may not need the individually-dated-window
 * trick at all. This pure function is correct and tested as-is regardless of
 * which scheduling layer ends up consuming it.
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
      val day = after.plusDays(dayOffset.toLong())
      dayOffset++
      val fires = day
        .withHour(reminder.hour)
        .withMinute(reminder.minute)
        .withSecond(0)
        .withNano(0)
      // Strictly after `now`, so rescheduling at 21:00:30 doesn't re-queue
      // the 21:00 that just fired.
      if (!fires.isAfter(after)) continue
      if (goalMetToday && fires.toLocalDate() == after.toLocalDate()) continue
      found.add(fires)
    }
    return found
  }
}
