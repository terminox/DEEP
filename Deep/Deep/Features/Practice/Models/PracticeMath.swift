import Foundation

/// How the member's rhythm moved today: the run of returning days as it stood
/// before today, and as it stands now. `after > before` exactly when today is
/// the day that extended it — the ending names that as a return.
struct ContinuityTransition: Equatable {
  /// Consecutive practice days ending yesterday.
  let before: Int
  /// Consecutive practice days ending today — or, while today has no practice
  /// yet, the run still alive from yesterday (the same number as `before`).
  let after: Int

  /// Whether today's practice is what extended the run.
  var returnedToday: Bool { after > before }
}

/// Pure aggregate math over the practice journal. The server keeps a dumb log;
/// everything the garden shows — today's minutes, streaks — is derived here,
/// in the user's own calendar, so day boundaries follow the device timezone.
///
/// Minutes and the session cap are DEEP Sessions only. The rhythm (streaks,
/// continuity) counts *any* practice day: a finished session, a sound listened
/// to its end, or a Global Pause the server counted.
enum PracticeMath {
  /// Whole minutes practised today. Any practice at all counts for at least a
  /// minute, so a single one-minute session never rounds away to nothing.
  static func minutesToday(
    in completions: [PracticeCompletion],
    calendar: Calendar,
    now: Date
  ) -> Int {
    let seconds = completions
      .filter { calendar.isDate($0.completedAt, inSameDayAs: now) }
      .reduce(0) { $0 + $1.durationSeconds }
    guard seconds > 0 else { return 0 }
    return max(1, seconds / 60)
  }

  /// Sessions completed today — the client mirror of the server's per-day
  /// session award rule (`RewardRules.deepSessionDailyLimit`), so the
  /// completion beat never promises a heart the sync will not deliver.
  static func completionsToday(
    in completions: [PracticeCompletion],
    calendar: Calendar,
    now: Date
  ) -> Int {
    completions.count { calendar.isDate($0.completedAt, inSameDayAs: now) }
  }

  // MARK: - Practice days

  /// Distinct local-midnight days with any practice: finished sessions, local
  /// activity markers, and the server's activity days ("YYYY-MM-DD", already
  /// in the member's own calendar). A day key that doesn't parse is skipped.
  static func practiceDays(
    completions: [PracticeCompletion],
    activities: [PracticeActivity] = [],
    remoteDays: [String] = [],
    calendar: Calendar
  ) -> Set<Date> {
    var days = Set(completions.map { calendar.startOfDay(for: $0.completedAt) })
    days.formUnion(activities.map { calendar.startOfDay(for: $0.at) })
    days.formUnion(remoteDays.compactMap { day(fromKey: $0, calendar: calendar) })
    return days
  }

  /// The local midnight a server day key names, e.g. "2026-07-23".
  ///
  /// The key is always a Gregorian date, whatever calendar the device uses:
  /// read through a Thai device's Buddhist calendar, "2026" would be year 2026
  /// BE (1483 AD) and no server day would ever count. So the key is parsed
  /// with a Gregorian calendar in the member's timezone, and only the instant
  /// it names goes back through `calendar`.
  static func day(fromKey key: String, calendar: Calendar) -> Date? {
    let parts = key.split(separator: "-", omittingEmptySubsequences: false).map { Int($0) }
    guard parts.count == 3,
          let year = parts[0], let month = parts[1], let day = parts[2],
          (1...12).contains(month), (1...31).contains(day)
    else { return nil }
    var gregorian = Calendar(identifier: .gregorian)
    gregorian.timeZone = calendar.timeZone
    // Noon rather than midnight: a midnight that a DST step skips doesn't exist.
    let components = DateComponents(year: year, month: month, day: day, hour: 12)
    guard let instant = gregorian.date(from: components),
          gregorian.component(.day, from: instant) == day
    else { return nil }
    return calendar.startOfDay(for: instant)
  }

  // MARK: - Streaks

  /// Consecutive practice days ending today — or yesterday, so a streak isn't
  /// "broken" while today simply hasn't happened yet.
  static func currentStreakDays(
    in completions: [PracticeCompletion],
    calendar: Calendar,
    now: Date
  ) -> Int {
    currentStreakDays(
      days: practiceDays(completions: completions, calendar: calendar),
      calendar: calendar,
      now: now
    )
  }

  static func currentStreakDays(days: Set<Date>, calendar: Calendar, now: Date) -> Int {
    continuityTransition(days: days, calendar: calendar, now: now).after
  }

  /// The run before today and the run now — see `ContinuityTransition`.
  static func continuityTransition(
    days: Set<Date>,
    calendar: Calendar,
    now: Date
  ) -> ContinuityTransition {
    let today = calendar.startOfDay(for: now)
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
      return ContinuityTransition(before: 0, after: 0)
    }
    let before = run(endingOn: yesterday, in: days, calendar: calendar)
    return ContinuityTransition(
      before: before,
      after: days.contains(today) ? before + 1 : before
    )
  }

  /// The longest run of consecutive practice days ever. Plant unlocks derive
  /// from this rather than the current streak, so growth never regresses.
  static func longestStreakDays(
    in completions: [PracticeCompletion],
    calendar: Calendar
  ) -> Int {
    longestStreakDays(
      days: practiceDays(completions: completions, calendar: calendar),
      calendar: calendar
    )
  }

  static func longestStreakDays(days: Set<Date>, calendar: Calendar) -> Int {
    var longest = 0
    var run = 0
    var previous: Date?
    for day in days.sorted() {
      if let previous,
         let next = calendar.date(byAdding: .day, value: 1, to: previous),
         calendar.isDate(next, inSameDayAs: day) {
        run += 1
      } else {
        run = 1
      }
      longest = max(longest, run)
      previous = day
    }
    return longest
  }

  /// Consecutive practice days counting back from `last` (inclusive).
  private static func run(endingOn last: Date, in days: Set<Date>, calendar: Calendar) -> Int {
    var cursor = last
    var streak = 0
    while days.contains(cursor),
          let previous = calendar.date(byAdding: .day, value: -1, to: cursor) {
      streak += 1
      cursor = previous
    }
    return streak
  }
}
