import Testing
import Foundation
@testable import Deep

/// Deterministic aggregate math, pinned to a fixed calendar/timezone/now so
/// day-boundary edge cases can't drift with wherever the test machine sits.
@MainActor
struct PracticeMathTests {
  private static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Bangkok")!
    return calendar
  }()

  /// 2026-07-23 12:00 Bangkok — a fixed "now" for every test below.
  private static let now = date(year: 2026, month: 7, day: 23, hour: 12)

  private static func date(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 12,
    minute: Int = 0
  ) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return calendar.date(from: components)!
  }

  private static func completion(
    durationSeconds: Int,
    on day: Date
  ) -> PracticeCompletion {
    PracticeCompletion(
      id: UUID(),
      title: "Balancing breath",
      durationSeconds: durationSeconds,
      completedAt: day,
      isSynced: true
    )
  }

  // MARK: - minutesToday

  @Test
  func minutesTodayCountsOnlySameDay() {
    let yesterdayLate = Self.date(year: 2026, month: 7, day: 22, hour: 23, minute: 59)
    let todayEarly = Self.date(year: 2026, month: 7, day: 23, hour: 0, minute: 1)
    let completions = [
      Self.completion(durationSeconds: 120, on: yesterdayLate),
      Self.completion(durationSeconds: 60, on: todayEarly),
    ]

    let minutes = PracticeMath.minutesToday(in: completions, calendar: Self.calendar, now: Self.now)
    #expect(minutes == 1)
  }

  @Test
  func minutesTodaySixtySecondsReadsOneMinute() {
    let completions = [Self.completion(durationSeconds: 60, on: Self.now)]
    let minutes = PracticeMath.minutesToday(in: completions, calendar: Self.calendar, now: Self.now)
    #expect(minutes == 1)
  }

  @Test
  func minutesTodayEmptyIsZero() {
    let minutes = PracticeMath.minutesToday(in: [], calendar: Self.calendar, now: Self.now)
    #expect(minutes == 0)
  }

  // MARK: - completionsToday

  @Test
  func completionsTodayCountsSessionsNotMinutes() {
    let yesterdayLate = Self.date(year: 2026, month: 7, day: 22, hour: 23, minute: 59)
    let completions = [
      Self.completion(durationSeconds: 300, on: Self.now),
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 23, hour: 8)),
      Self.completion(durationSeconds: 600, on: yesterdayLate),
    ]

    let count = PracticeMath.completionsToday(
      in: completions, calendar: Self.calendar, now: Self.now
    )
    #expect(count == 2)
  }

  @Test
  func completionsTodayEmptyIsZero() {
    let count = PracticeMath.completionsToday(in: [], calendar: Self.calendar, now: Self.now)
    #expect(count == 0)
  }

  // MARK: - currentStreakDays

  @Test
  func currentStreakCountsBackFromToday() {
    let completions = [
      Self.completion(durationSeconds: 60, on: Self.now),
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 22)),
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 21)),
    ]

    let streak = PracticeMath.currentStreakDays(in: completions, calendar: Self.calendar, now: Self.now)
    #expect(streak == 3)
  }

  @Test
  func currentStreakStillAliveWhenTodayEmptyButYesterdayPracticed() {
    let completions = [
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 22)),
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 21)),
    ]

    let streak = PracticeMath.currentStreakDays(in: completions, calendar: Self.calendar, now: Self.now)
    #expect(streak == 2)
  }

  @Test
  func currentStreakBrokenByMissedDayIsZero() {
    // Neither today (23rd) nor yesterday (22nd) has practice — the streak
    // that ended on the 20th is broken.
    let completions = [
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 20)),
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 19)),
    ]

    let streak = PracticeMath.currentStreakDays(in: completions, calendar: Self.calendar, now: Self.now)
    #expect(streak == 0)
  }

  // MARK: - longestStreakDays

  @Test
  func longestStreakPicksTheLongestRunOverGaps() {
    let completions = [
      // A 2-day run.
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 1)),
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 2)),
      // A gap, then a 4-day run — the longest.
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 10)),
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 11)),
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 12)),
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 13)),
      // A single day after another gap.
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 20)),
    ]

    let longest = PracticeMath.longestStreakDays(in: completions, calendar: Self.calendar)
    #expect(longest == 4)
  }

  @Test
  func longestStreakEmptyIsZero() {
    let longest = PracticeMath.longestStreakDays(in: [], calendar: Self.calendar)
    #expect(longest == 0)
  }
}
