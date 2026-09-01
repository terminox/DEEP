import Foundation

/// When the daily reminder should fire, as pure arithmetic.
///
/// iOS caps an app at 64 pending notification requests, and a *repeating*
/// calendar trigger — one request, forever — cannot skip a single occurrence.
/// Skipping matters here: a day whose practice is already done should pass in
/// silence, because being reminded to do what you have already done is exactly
/// the "you are behind" register `DESIGN.md` rules out. So the schedule is a
/// window of individually dated requests, rebuilt every time the app comes
/// forward. Eight weeks of them sits comfortably under the cap, and someone
/// who hasn't opened Deep in eight weeks has a bigger gap than a notification
/// closes.
///
/// Kept free of `UNUserNotificationCenter` on purpose: the date maths is the
/// part worth testing, and it tests as a pure function (the `PracticeMath`
/// pattern).
enum ReminderSchedule {
  /// How many future occurrences to keep queued.
  static let horizon = 56

  /// The next `horizon` firing times after `now`.
  ///
  /// - Parameter goalMetToday: today's practice is already complete, so
  ///   today's occurrence is dropped. Only today can be known this way; every
  ///   later day is scheduled and withdrawn later if it turns out the same.
  static func occurrences(
    after now: Date,
    reminder: DailyReminder,
    goalMetToday: Bool,
    calendar: Calendar = .current,
    limit: Int = horizon
  ) -> [Date] {
    guard reminder.isEnabled, limit > 0 else { return [] }

    var found: [Date] = []
    var dayOffset = 0
    // A bounded walk rather than `while true`: a DST-skipped or otherwise
    // unrepresentable wall time must never spin here.
    while found.count < limit, dayOffset < limit + 7 {
      defer { dayOffset += 1 }
      guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
            let fires = calendar.date(
              bySettingHour: reminder.hour,
              minute: reminder.minute,
              second: 0,
              of: day
            )
      else { continue }
      // Strictly after `now`, so rescheduling at 21:00:30 doesn't re-queue the
      // 21:00 that just fired.
      guard fires > now else { continue }
      if goalMetToday, calendar.isDate(fires, inSameDayAs: now) { continue }
      found.append(fires)
    }
    return found
  }
}
