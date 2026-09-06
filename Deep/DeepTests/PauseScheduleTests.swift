import Testing
import Foundation
@testable import Deep

/// What the card counts down to once a day can hold more than one pause.
///
/// The regression these guard: `nextMeditationStart` used to project the same
/// wall clock 24 hours on, which was exact when there was one session a day and
/// wrong twice a day as soon as there were two — most damagingly to someone
/// still writing their reflection after the morning session, told the next
/// pause is tomorrow when there is one that evening.
struct PauseScheduleTests {
  private let meditationStart = Date(timeIntervalSince1970: 1_788_000_000)

  private func schedule(nextOccurrenceMeditationStart: Date? = nil) -> PauseSchedule {
    let lobby = meditationStart.addingTimeInterval(-10 * 60)
    let welcome = meditationStart.addingTimeInterval(-10)
    let feedback = meditationStart.addingTimeInterval(10 * 60)
    let end = meditationStart.addingTimeInterval(20 * 60)
    return PauseSchedule(
      pauseDate: "2026-09-05",
      timezone: "Asia/Bangkok",
      phases: [
        PausePhaseWindow(key: .lobby, startsAt: lobby, endsAt: welcome),
        PausePhaseWindow(key: .welcome, startsAt: welcome, endsAt: meditationStart),
        PausePhaseWindow(key: .meditation, startsAt: meditationStart, endsAt: feedback),
        PausePhaseWindow(key: .feedback, startsAt: feedback, endsAt: end),
      ],
      lobbyAudioURL: nil,
      lobbyDuration: 262,
      meditationAudioURL: nil,
      meditationDuration: 600,
      nextOccurrenceMeditationStart: nextOccurrenceMeditationStart,
      welcomeMessages: [],
      intentions: []
    )
  }

  @Test("While this occurrence is still ahead, it is what comes next")
  func thisOccurrenceWhileAhead() {
    let schedule = schedule(
      nextOccurrenceMeditationStart: meditationStart.addingTimeInterval(12 * 3600)
    )
    let beforeItStarts = meditationStart.addingTimeInterval(-5 * 60)
    #expect(schedule.nextMeditationStart(after: beforeItStarts) == meditationStart)
  }

  @Test("Inside the reflection phase, the card names the evening session, not tomorrow")
  func followsTheServersNextOccurrence() {
    // The headline case: the morning meditation has ended, the member is in the
    // feedback phase, and the next pause is twelve hours away — not a day.
    let tonight = meditationStart.addingTimeInterval(12 * 3600)
    let schedule = schedule(nextOccurrenceMeditationStart: tonight)
    let writingReflection = meditationStart.addingTimeInterval(15 * 60)
    #expect(schedule.nextMeditationStart(after: writingReflection) == tonight)
  }

  @Test("A server that runs one pause a day still projects tomorrow")
  func projectsTomorrowWithoutTheField() {
    // No field, so the 24h projection stands — and on such a server it is exact
    // rather than a guess. This is what keeps a new build against an old server
    // behaving precisely as it does today.
    let schedule = schedule(nextOccurrenceMeditationStart: nil)
    let afterItStarted = meditationStart.addingTimeInterval(60)
    #expect(
      schedule.nextMeditationStart(after: afterItStarted)
        == meditationStart.addingTimeInterval(24 * 60 * 60)
    )
  }

  @Test("A next occurrence at or before this one is ignored")
  func ignoresANonAdvancingNextOccurrence() {
    // Guards a server echoing this occurrence's own start, which would otherwise
    // pin the countdown target permanently in the past.
    let schedule = schedule(nextOccurrenceMeditationStart: meditationStart)
    let afterItStarted = meditationStart.addingTimeInterval(60)
    #expect(
      schedule.nextMeditationStart(after: afterItStarted)
        == meditationStart.addingTimeInterval(24 * 60 * 60)
    )
  }

  @Test("Without a meditation phase there is nothing to count down to")
  func nilWithoutAMeditation() {
    // Was a `return date` sentinel, which quietly made the card count down to
    // right now.
    let empty = PauseSchedule(
      pauseDate: "2026-09-05",
      timezone: "Asia/Bangkok",
      phases: [],
      lobbyAudioURL: nil,
      lobbyDuration: 0,
      meditationAudioURL: nil,
      meditationDuration: 0,
      welcomeMessages: [],
      intentions: []
    )
    #expect(empty.nextMeditationStart(after: meditationStart) == nil)
    #expect(empty.windowEnd == nil)
  }

  @Test("windowEnd is the last phase edge")
  func windowEndIsTheLastEdge() {
    #expect(schedule().windowEnd == meditationStart.addingTimeInterval(20 * 60))
  }

  @Test("The schedule line reads in the member's own clock, with no zone named")
  func scheduleLineIsLocal() throws {
    // The evening session: 20:40 Bangkok on 6 September 2026. Zone and locale
    // are pinned so the assertion is not hostage to the machine running it.
    let bangkok = TimeZone(identifier: "Asia/Bangkok")!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = bangkok
    let target = try #require(
      calendar.date(
        from: DateComponents(year: 2026, month: 9, day: 6, hour: 20, minute: 40)
      )
    )
    let english = Locale(identifier: "en_US")

    let inBangkok = PauseScheduleLine.text(
      target: target,
      now: target.addingTimeInterval(-2 * 3600), // 18:40 the same evening
      timeZone: bangkok,
      locale: english
    )
    // Asserted in two parts rather than against one literal: Date.FormatStyle
    // separates the time from AM/PM with a narrow no-break space (U+202F), not
    // the ordinary one anybody types into a test.
    #expect(inBangkok.hasPrefix("Today · 8:40"))
    #expect(inBangkok.hasSuffix("PM"))
    // The zone is never named: "Asia/Bangkok" localizes to "Indochina Time" or
    // "GMT+7", so there is nothing worth printing.
    #expect(!inBangkok.contains("Thailand"))

    // The same instant, two hours earlier, read in Auckland — where it has
    // already tipped into tomorrow. Two members seeing different words for one
    // moment is the point, and the old Bangkok-calendar comparison got this
    // wrong: it said "Today" here.
    let fromAuckland = PauseScheduleLine.text(
      target: target,
      now: target.addingTimeInterval(-2 * 3600),
      timeZone: TimeZone(identifier: "Pacific/Auckland")!,
      locale: english
    )
    #expect(fromAuckland.hasPrefix("Tomorrow"))
  }
}
