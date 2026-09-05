import Testing
import Foundation
@testable import Deep

/// What happens when the occurrence the app is holding runs out.
///
/// With one pause a day, waiting a minute to notice cost nothing — the answer
/// was always "the same time tomorrow". With several, only the server knows
/// what comes next, and the wait is visible: the card names the wrong session
/// until the fetch lands, and a countdown that should have opened cleanly pops
/// in part-way through.
@MainActor
struct GlobalPauseScheduleRolloverTests {
  private struct StubError: Error {}

  /// Hands out scripted schedules and counts how often it was asked.
  @MainActor
  private final class StubPauseEventRepository: PauseEventRepository {
    private(set) var scheduleCalls = 0
    private var scripted: [Result<PauseSchedule, Error>]
    private let repeating: Result<PauseSchedule, Error>

    /// `scripted` answers the first calls in order; every later call repeats
    /// the last entry.
    init(_ scripted: [Result<PauseSchedule, Error>]) {
      self.scripted = scripted
      self.repeating = scripted.last!
    }

    func schedule() async throws -> PauseSchedule {
      defer { scheduleCalls += 1 }
      let answer = scheduleCalls < scripted.count ? scripted[scheduleCalls] : repeating
      return try answer.get()
    }

    func live() async throws -> PauseLiveSnapshot {
      PauseLiveSnapshot(
        serverNow: Date(),
        participantCount: 0,
        byCountry: [:],
        byContinent: [:],
        locations: [],
        unlocatedByCountry: [:],
        recentJoins: []
      )
    }

    @discardableResult
    func heartbeat(presenceID: String, countryISO: String?) async throws -> PauseJoinPoint? { nil }
    func leave(presenceID: String) async {}
    func messages(limit: Int, cursor: String?) async throws -> PeaceMessagesPage {
      PeaceMessagesPage(messages: [], nextCursor: nil)
    }
    func postMessage(
      _ text: String,
      countryISO: String?,
      intention: String?
    ) async throws -> PostedPeaceMessage {
      throw StubError()
    }
    func submitReflection(intention: String?, mood: String?) async throws {}
  }

  /// An occurrence whose meditation starts `offset` from now, optionally
  /// naming the one after it.
  private func occurrence(
    meditationIn offset: TimeInterval,
    nextIn nextOffset: TimeInterval? = nil
  ) -> PauseSchedule {
    let meditation = Date().addingTimeInterval(offset)
    return PauseSchedule(
      pauseDate: "2026-09-05",
      timezone: "Asia/Bangkok",
      phases: [
        PausePhaseWindow(
          key: .lobby,
          startsAt: meditation.addingTimeInterval(-600),
          endsAt: meditation.addingTimeInterval(-10)
        ),
        PausePhaseWindow(
          key: .welcome,
          startsAt: meditation.addingTimeInterval(-10),
          endsAt: meditation
        ),
        PausePhaseWindow(
          key: .meditation,
          startsAt: meditation,
          endsAt: meditation.addingTimeInterval(600)
        ),
        PausePhaseWindow(
          key: .feedback,
          startsAt: meditation.addingTimeInterval(600),
          endsAt: meditation.addingTimeInterval(1200)
        ),
      ],
      lobbyAudioURL: nil,
      lobbyDuration: 0,
      meditationAudioURL: nil,
      meditationDuration: 600,
      nextOccurrenceMeditationStart: nextOffset.map { Date().addingTimeInterval($0) },
      welcomeMessages: [],
      intentions: []
    )
  }

  /// Waits, bounded, for the repository to have been asked `count` times.
  private func waitForCalls(
    _ count: Int,
    on stub: StubPauseEventRepository
  ) async throws {
    for _ in 0..<200 where stub.scheduleCalls < count {
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(stub.scheduleCalls >= count)
  }

  /// Asserts the app has stopped asking: the tally settles and stays settled.
  ///
  /// Deliberately not an exact count. Suites run in parallel and the session
  /// refreshes on `willEnterForeground` of its own accord, so an incidental
  /// extra fetch is not a bug — a *loop* is, and a broken latch fails this by
  /// hundreds rather than by one.
  private func expectFetchingHasStopped(_ stub: StubPauseEventRepository) async throws {
    try await Task.sleep(for: .milliseconds(200))
    let settled = stub.scheduleCalls
    try await Task.sleep(for: .milliseconds(400))
    #expect(stub.scheduleCalls == settled)
  }

  @Test("A spent occurrence is re-fetched at once, not a minute later")
  func spentOccurrenceIsRefetchedImmediately() async throws {
    // An occurrence whose whole window closed an hour ago, replaced by one
    // starting in ten minutes — the shape of crossing a session boundary.
    let stub = StubPauseEventRepository([
      .success(occurrence(meditationIn: -3600)),
      .success(occurrence(meditationIn: 600, nextIn: 12 * 3600)),
    ])
    let session = GlobalPauseSession(clock: SyncedClock(), repository: stub)

    await session.start()
    try await waitForCalls(2, on: stub)

    // And the card is now counting down to the session it just learned about.
    #expect(session.nextMeditationStart != nil)
    let target = try #require(session.nextMeditationStart)
    #expect(target.timeIntervalSinceNow > 0)
  }

  @Test("A server still handing back the spent occurrence is not re-fetched in a loop")
  func aStaleServerIsNotPolledInALoop() async throws {
    // The zero-backoff guard the boundary timer's comment has been asking for
    // since it was written: one extra request, then the 60s backoff.
    let stub = StubPauseEventRepository([.success(occurrence(meditationIn: -3600))])
    let session = GlobalPauseSession(clock: SyncedClock(), repository: stub)

    await session.start()
    try await waitForCalls(2, on: stub)
    try await expectFetchingHasStopped(stub)
  }

  @Test("A failed re-fetch of a spent occurrence backs off rather than hammering")
  func aFailedRefetchBacksOff() async throws {
    // refreshSchedule keeps the old schedule on failure, on purpose, so the
    // latch stays set and the retry path is the 60s one.
    let stub = StubPauseEventRepository([
      .success(occurrence(meditationIn: -3600)),
      .failure(StubError()),
    ])
    let session = GlobalPauseSession(clock: SyncedClock(), repository: stub)

    await session.start()
    try await waitForCalls(2, on: stub)
    try await expectFetchingHasStopped(stub)
  }

  @Test("A current occurrence is not re-fetched")
  func aCurrentOccurrenceIsLeftAlone() async throws {
    let stub = StubPauseEventRepository([
      .success(occurrence(meditationIn: 3600, nextIn: 12 * 3600))
    ])
    let session = GlobalPauseSession(clock: SyncedClock(), repository: stub)

    await session.start()
    try await expectFetchingHasStopped(stub)
  }
}
