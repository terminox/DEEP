import Testing
import Foundation
@testable import Deep

/// The reminder's date maths, tested as the pure function it is — the
/// `PracticeMath` pattern. Everything here runs off an injected calendar and a
/// fixed `now`, so no test depends on when it runs.
@Suite("Reminder schedule")
struct ReminderScheduleTests {
  private var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Bangkok")!
    return c
  }

  private func date(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(identifier: "Asia/Bangkok")
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: iso)!
  }

  private let enabled = DailyReminder(isEnabled: true, hour: 21, minute: 0)

  @Test("a disabled reminder queues nothing")
  func disabledQueuesNothing() {
    let occurrences = ReminderSchedule.occurrences(
      after: date("2026-09-01T08:00:00+07:00"),
      reminder: DailyReminder(isEnabled: false, hour: 21, minute: 0),
      goalMetToday: false,
      calendar: calendar
    )
    #expect(occurrences.isEmpty)
  }

  @Test("fills the whole window, one per day")
  func fillsWindow() {
    let occurrences = ReminderSchedule.occurrences(
      after: date("2026-09-01T08:00:00+07:00"),
      reminder: enabled,
      goalMetToday: false,
      calendar: calendar
    )
    #expect(occurrences.count == ReminderSchedule.horizon)

    let days = Set(occurrences.map { calendar.startOfDay(for: $0) })
    #expect(days.count == occurrences.count, "each occurrence falls on its own day")

    // Every one lands on the chosen clock face.
    for occurrence in occurrences {
      let parts = calendar.dateComponents([.hour, .minute], from: occurrence)
      #expect(parts.hour == 21)
      #expect(parts.minute == 0)
    }
  }

  @Test("today is included when the time is still ahead")
  func includesTodayBeforeTheHour() {
    let now = date("2026-09-01T08:00:00+07:00")
    let occurrences = ReminderSchedule.occurrences(
      after: now, reminder: enabled, goalMetToday: false, calendar: calendar
    )
    #expect(calendar.isDate(occurrences[0], inSameDayAs: now))
  }

  @Test("today is skipped once its time has passed")
  func skipsTodayAfterTheHour() {
    let now = date("2026-09-01T21:30:00+07:00")
    let occurrences = ReminderSchedule.occurrences(
      after: now, reminder: enabled, goalMetToday: false, calendar: calendar
    )
    #expect(!calendar.isDate(occurrences[0], inSameDayAs: now))
    #expect(occurrences.count == ReminderSchedule.horizon, "the window still fills")
  }

  @Test("a day whose practice is done stays quiet")
  func skipsTodayWhenGoalMet() {
    let now = date("2026-09-01T08:00:00+07:00")
    let occurrences = ReminderSchedule.occurrences(
      after: now, reminder: enabled, goalMetToday: true, calendar: calendar
    )
    #expect(!calendar.isDate(occurrences[0], inSameDayAs: now))
    // Tomorrow is not skipped — only today can be known to be complete.
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
    #expect(calendar.isDate(occurrences[0], inSameDayAs: tomorrow))
  }

  @Test("the window stays under the system's 64-request cap")
  func staysUnderSystemCap() {
    #expect(ReminderSchedule.horizon < 64)
  }

  @Test("every occurrence is in the future")
  func allFuture() {
    let now = date("2026-09-01T20:59:59+07:00")
    let occurrences = ReminderSchedule.occurrences(
      after: now, reminder: enabled, goalMetToday: false, calendar: calendar
    )
    #expect(occurrences.allSatisfy { $0 > now })
  }

  @Test("one identifier per day, stable across rebuilds")
  func identifiersAreStablePerDay() {
    let day = date("2026-09-01T21:00:00+07:00")
    let first = ReminderScheduler.identifier(for: day, calendar: calendar)
    let second = ReminderScheduler.identifier(for: day, calendar: calendar)
    #expect(first == second)
    #expect(first == "deep.reminder.2026-09-01")

    let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
    #expect(ReminderScheduler.identifier(for: nextDay, calendar: calendar) != first)
  }

  @Test("copy rotates by day and holds still within one")
  func copyRotatesDaily() {
    let day = date("2026-09-01T21:00:00+07:00")
    let sameDayLater = date("2026-09-01T23:00:00+07:00")
    #expect(
      ReminderCopy.forDay(of: day, calendar: calendar)
        == ReminderCopy.forDay(of: sameDayLater, calendar: calendar)
    )

    // A week of consecutive days should exhaust the pool rather than repeat.
    let week = (0..<ReminderCopy.pool.count).map {
      ReminderCopy.forDay(of: calendar.date(byAdding: .day, value: $0, to: day)!, calendar: calendar)
    }
    #expect(Set(week.map(\.title)).count == ReminderCopy.pool.count)
  }
}
