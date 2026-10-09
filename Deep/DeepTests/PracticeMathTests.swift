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

  // MARK: - Any practice keeps the day

  @Test("A day with only a finished track bridges the gap between sessions")
  func trackOnlyDayBridgesTheGap() {
    let completions = [
      Self.completion(durationSeconds: 60, on: Self.now),
      Self.completion(durationSeconds: 60, on: Self.date(year: 2026, month: 7, day: 21)),
    ]
    let activities = [
      PracticeActivity(kind: .track, at: Self.date(year: 2026, month: 7, day: 22, hour: 21)),
    ]
    let days = PracticeMath.practiceDays(
      completions: completions, activities: activities, calendar: Self.calendar
    )

    #expect(PracticeMath.currentStreakDays(days: days, calendar: Self.calendar, now: Self.now) == 3)
    #expect(PracticeMath.longestStreakDays(days: days, calendar: Self.calendar) == 3)
  }

  @Test("Server activity days join the session days")
  func serverDaysUnionWithSessions() {
    let completions = [Self.completion(durationSeconds: 60, on: Self.now)]
    let days = PracticeMath.practiceDays(
      completions: completions,
      remoteDays: ["2026-07-22", "2026-07-21", "2026-07-23", "not-a-day"],
      calendar: Self.calendar
    )

    #expect(days.count == 3)
    #expect(PracticeMath.currentStreakDays(days: days, calendar: Self.calendar, now: Self.now) == 3)
  }

  @Test("Minutes stay sessions-only even when other practice kept the day")
  func minutesIgnoreActivities() {
    let minutes = PracticeMath.minutesToday(in: [], calendar: Self.calendar, now: Self.now)
    let days = PracticeMath.practiceDays(
      completions: [],
      activities: [PracticeActivity(kind: .pause, at: Self.now)],
      calendar: Self.calendar
    )

    #expect(minutes == 0)
    #expect(days.count == 1)
  }

  // MARK: - Calendars

  /// What a Thai device's `Calendar.current` is: Buddhist era, Thai locale.
  private static let buddhist: Calendar = {
    var calendar = Calendar(identifier: .buddhist)
    calendar.timeZone = TimeZone(identifier: "Asia/Bangkok")!
    calendar.locale = Locale(identifier: "th_TH")
    return calendar
  }()

  @Test("Server day keys stay Gregorian on a Thai device's Buddhist calendar")
  func dayKeysParseUnderBuddhistCalendar() throws {
    let day = try #require(PracticeMath.day(fromKey: "2026-10-09", calendar: Self.buddhist))

    #expect(day == Self.calendar.startOfDay(for: Self.date(year: 2026, month: 10, day: 9)))
    // The same instant, read back in the Buddhist era.
    #expect(Self.buddhist.component(.year, from: day) == 2569)
    #expect(Self.buddhist.startOfDay(for: day) == day)
  }

  @Test("Server activity days keep a Thai device's streak")
  func serverDaysCountUnderBuddhistCalendar() {
    let completions = [Self.completion(durationSeconds: 60, on: Self.now)]
    let days = PracticeMath.practiceDays(
      completions: completions,
      remoteDays: ["2026-07-21", "2026-07-22"],
      calendar: Self.buddhist
    )

    #expect(days.count == 3)
    #expect(PracticeMath.currentStreakDays(days: days, calendar: Self.buddhist, now: Self.now) == 3)
    #expect(
      PracticeMath.continuityTransition(days: days, calendar: Self.buddhist, now: Self.now)
        == ContinuityTransition(before: 2, after: 3)
    )
  }

  @Test("Day keys that name no real date are skipped")
  func malformedDayKeysAreSkipped() {
    for key in ["2026-02-30", "2026-13-01", "2026-00-10", "2026-07", "2026--07-01", "2569-ต.ค.-09", ""] {
      #expect(PracticeMath.day(fromKey: key, calendar: Self.buddhist) == nil, "\(key)")
    }
  }

  // MARK: - continuityTransition

  private static func days(_ dayNumbers: [Int]) -> Set<Date> {
    Set(dayNumbers.map { calendar.startOfDay(for: date(year: 2026, month: 7, day: $0)) })
  }

  @Test("Yesterday kept, today practised: N → N+1")
  func transitionExtendsTheRun() {
    let transition = PracticeMath.continuityTransition(
      days: Self.days([20, 21, 22, 23]), calendar: Self.calendar, now: Self.now
    )
    #expect(transition == ContinuityTransition(before: 3, after: 4))
    #expect(transition.returnedToday)
  }

  @Test("Yesterday kept, today not yet: the run continues unmoved")
  func transitionHoldsBeforeTodaysPractice() {
    let transition = PracticeMath.continuityTransition(
      days: Self.days([21, 22]), calendar: Self.calendar, now: Self.now
    )
    #expect(transition == ContinuityTransition(before: 2, after: 2))
    #expect(transition.returnedToday == false)
  }

  @Test("A gap yesterday, today practised: 0 → 1")
  func transitionRestartsAfterAGap() {
    let transition = PracticeMath.continuityTransition(
      days: Self.days([19, 20, 23]), calendar: Self.calendar, now: Self.now
    )
    #expect(transition == ContinuityTransition(before: 0, after: 1))
  }

  @Test("A gap yesterday and nothing today: 0 → 0")
  func transitionEmptyWhenTheRunIsBroken() {
    let transition = PracticeMath.continuityTransition(
      days: Self.days([19, 20]), calendar: Self.calendar, now: Self.now
    )
    #expect(transition == ContinuityTransition(before: 0, after: 0))
  }
}
