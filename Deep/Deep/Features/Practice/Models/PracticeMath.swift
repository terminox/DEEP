import Foundation

/// Pure aggregate math over the practice journal. The server keeps a dumb log;
/// everything the garden shows — today's minutes, streaks — is derived here,
/// in the user's own calendar, so day boundaries follow the device timezone.
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

  /// Consecutive practice days ending today — or yesterday, so a streak isn't
  /// "broken" while today simply hasn't happened yet.
  static func currentStreakDays(
    in completions: [PracticeCompletion],
    calendar: Calendar,
    now: Date
  ) -> Int {
    let days = practiceDays(in: completions, calendar: calendar)
    let today = calendar.startOfDay(for: now)
    guard var cursor = days.contains(today)
      ? today
      : calendar.date(byAdding: .day, value: -1, to: today)
    else { return 0 }

    var streak = 0
    while days.contains(cursor),
          let previous = calendar.date(byAdding: .day, value: -1, to: cursor) {
      streak += 1
      cursor = previous
    }
    return streak
  }

  /// The longest run of consecutive practice days ever. Plant unlocks derive
  /// from this rather than the current streak, so growth never regresses.
  static func longestStreakDays(
    in completions: [PracticeCompletion],
    calendar: Calendar
  ) -> Int {
    let days = practiceDays(in: completions, calendar: calendar).sorted()
    var longest = 0
    var run = 0
    var previous: Date?
    for day in days {
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

  /// Distinct local-midnight days with at least one completion.
  private static func practiceDays(
    in completions: [PracticeCompletion],
    calendar: Calendar
  ) -> Set<Date> {
    Set(completions.map { calendar.startOfDay(for: $0.completedAt) })
  }
}
