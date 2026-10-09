import Testing
import Foundation
@testable import Deep

/// The durable listen report behind sound hearts. The regressions it guards:
/// a report was a one-shot `try?`, so any network blip silently cost the
/// heart; and a correct heart arrived with no word at all, so the rules read
/// as random.
@MainActor
struct ListenReporterTests {
  /// A scripted `/me/sound/listens`: answers in order, then grants by default.
  @MainActor
  final class ListenServer {
    enum Reply {
      case outcome(ListenOutcome)
      case failure(Error)
    }

    var replies: [Reply] = []
    /// Yield a few times mid-request, so overlapping flushes would interleave.
    var suspends = false
    private(set) var calls: [(trackId: String, completedAt: Date)] = []
    private(set) var maxInFlight = 0
    private var inFlight = 0

    func report(_ trackId: String, _ completedAt: Date) async throws -> ListenOutcome {
      calls.append((trackId, completedAt))
      inFlight += 1
      maxInFlight = max(maxInFlight, inFlight)
      defer { inFlight -= 1 }
      if suspends {
        for _ in 0..<5 { await Task.yield() }
      }
      let reply = replies.isEmpty ? .outcome(.granted(earned: 1)) : replies.removeFirst()
      switch reply {
      case .outcome(let outcome): return outcome
      case .failure(let error): throw error
      }
    }
  }

  /// A hand-cranked clock.
  final class Clock {
    var now: Date
    init(_ now: Date) { self.now = now }
  }

  /// Everything one reporter talks to, kept so tests can look.
  struct Rig {
    let reporter: ListenReporter
    let server: ListenServer
    let clock: Clock
    let practice: MockPracticeStore
    let defaults: UserDefaults
    let grants: Box<[AwardGrant]>
    let announcements: Box<[String]>
  }

  final class Box<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
  }

  /// 2027-01-15 08:00 UTC — mid-morning, so an hour either way is the same day.
  private static let morning = Date(timeIntervalSince1970: 1_800_000_000)

  private static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()

  private func freshDefaults(_ suite: String) -> UserDefaults {
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
  }

  private func makeRig(
    suite: String,
    defaults: UserDefaults? = nil,
    server: ListenServer? = nil,
    clock: Clock? = nil,
    calendar: Calendar = ListenReporterTests.calendar
  ) -> Rig {
    let server = server ?? ListenServer()
    let defaults = defaults ?? freshDefaults(suite)
    let clock = clock ?? Clock(Self.morning)
    let practice = MockPracticeStore()
    let grants = Box<[AwardGrant]>([])
    let announcements = Box<[String]>([])
    let reporter = ListenReporter(
      report: { try await server.report($0, $1) },
      practiceStore: practice,
      defaults: defaults,
      calendar: calendar,
      now: { clock.now },
      // Long enough that no notice expires mid-test; tests step through a
      // sequence with `advanceNotice()`.
      noticeDuration: .seconds(3_600),
      announce: { announcements.value.append($0) }
    )
    reporter.awardSink = { grants.value.append($0) }
    return Rig(
      reporter: reporter,
      server: server,
      clock: clock,
      practice: practice,
      defaults: defaults,
      grants: grants,
      announcements: announcements
    )
  }

  // MARK: - Queue

  @Test("A listen lost to the network is kept, survives a relaunch, and lands on retry")
  func persistsAndRetries() async {
    let suite = "deep.listens.test.retry"
    let rig = makeRig(suite: suite)
    rig.server.replies = [.failure(APIError.transport("offline"))]

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    await rig.reporter.flush()
    #expect(rig.reporter.hasPending)
    #expect(rig.grants.value.isEmpty)

    // A relaunch reads the same queue back and delivers it, finish time intact.
    let relaunched = makeRig(suite: suite, defaults: rig.defaults, server: rig.server)
    #expect(relaunched.reporter.hasPending)
    await relaunched.reporter.flush()

    #expect(relaunched.reporter.hasPending == false)
    #expect(relaunched.grants.value.count == 1)
    #expect(rig.server.calls.count == 2)
    #expect(rig.server.calls.last?.trackId == "rain")
    #expect(rig.server.calls.last?.completedAt == Self.morning)
  }

  @Test("A 5xx or an expired session keeps the listen for later")
  func serverAndAuthFailuresKeep() async {
    let rig = makeRig(suite: "deep.listens.test.keep")
    rig.server.replies = [
      .failure(APIError.http(status: 503, code: "unavailable", message: "")),
      .failure(APIError.unauthorized),
    ]

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    await rig.reporter.flush()
    #expect(rig.reporter.hasPending)

    await rig.reporter.flush()
    #expect(rig.reporter.hasPending)

    await rig.reporter.flush()
    #expect(rig.reporter.hasPending == false)
    #expect(rig.server.calls.count == 3)
  }

  @Test("A track the server no longer has is dropped, not retried forever")
  func notFoundDrops() async {
    let rig = makeRig(suite: "deep.listens.test.404")
    rig.server.replies = [
      .failure(APIError.http(status: 404, code: "track_not_found", message: "Track not found")),
    ]

    rig.reporter.record(trackId: "gone", finishedAt: Self.morning)
    await rig.reporter.flush()

    #expect(rig.reporter.hasPending == false)
    #expect(rig.reporter.notice == nil)
    await rig.reporter.flush()
    #expect(rig.server.calls.count == 1)
  }

  @Test("A listen the server declines to place (stale) is dropped silently")
  func staleDrops() async {
    let rig = makeRig(suite: "deep.listens.test.stale")
    rig.server.replies = [.outcome(.stale)]

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    await rig.reporter.flush()

    #expect(rig.reporter.hasPending == false)
    #expect(rig.reporter.notice == nil)
    #expect(rig.announcements.value.isEmpty)
  }

  @Test("Listens older than 48h are pruned without a request")
  func prunesAfterRetention() async {
    let rig = makeRig(suite: "deep.listens.test.prune")
    rig.server.replies = [.failure(APIError.transport("offline"))]

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    await rig.reporter.flush()
    #expect(rig.reporter.hasPending)

    rig.clock.now = Self.morning.addingTimeInterval(49 * 60 * 60)
    #expect(rig.reporter.hasPending == false)
    await rig.reporter.flush()

    #expect(rig.reporter.pending.isEmpty)
    #expect(rig.server.calls.count == 1)
  }

  @Test("The same track finished twice in a day is queued once; a new day queues again")
  func dedupesPerTrackPerDay() async {
    let rig = makeRig(suite: "deep.listens.test.dedupe")
    rig.server.replies = Array(repeating: .failure(APIError.transport("offline")), count: 10)

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    rig.reporter.record(trackId: "rain", finishedAt: Self.morning.addingTimeInterval(60 * 60))
    rig.reporter.record(trackId: "waves", finishedAt: Self.morning.addingTimeInterval(2 * 60 * 60))
    rig.reporter.record(trackId: "rain", finishedAt: Self.morning.addingTimeInterval(24 * 60 * 60))
    await rig.reporter.flush()

    #expect(rig.reporter.pending.map(\.trackId) == ["rain", "waves", "rain"])
  }

  @Test("A Thai device's Buddhist calendar dedupes and stamps by the same days")
  func buddhistCalendarDays() async {
    var buddhist = Calendar(identifier: .buddhist)
    buddhist.timeZone = TimeZone(identifier: "UTC")!
    buddhist.locale = Locale(identifier: "th_TH")
    let rig = makeRig(suite: "deep.listens.test.buddhist", calendar: buddhist)
    rig.server.replies = Array(repeating: .failure(APIError.transport("offline")), count: 10)

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    rig.reporter.record(trackId: "rain", finishedAt: Self.morning.addingTimeInterval(60 * 60))
    rig.reporter.record(trackId: "rain", finishedAt: Self.morning.addingTimeInterval(24 * 60 * 60))
    await rig.reporter.flush()
    #expect(rig.reporter.pending.count == 2)

    // Today's-hearts-are-in is said once a Buddhist day, as on any calendar.
    rig.clock.now = Self.morning.addingTimeInterval(24 * 60 * 60)
    rig.reporter.reset()
    rig.server.replies = [
      .outcome(.capped("kind_cap", earned: 3)),
      .outcome(.capped("kind_cap", earned: 3)),
    ]
    rig.reporter.record(trackId: "waves", finishedAt: rig.clock.now)
    await rig.reporter.flush()
    #expect(rig.reporter.notice?.kind == .dayComplete(perDay: 3))
    rig.reporter.advanceNotice()
    rig.reporter.record(trackId: "wind", finishedAt: rig.clock.now)
    await rig.reporter.flush()
    #expect(rig.reporter.notice == nil)
  }

  @Test("A notice's haptic is claimed once, however many surfaces show it")
  func hapticClaimedOnce() async {
    let rig = makeRig(suite: "deep.listens.test.haptic")

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    await rig.reporter.flush()
    guard let first = rig.reporter.notice else {
      Issue.record("expected a notice")
      return
    }

    // Now Playing and the mini player both see the same notice.
    #expect(rig.reporter.claimHaptic(for: first))
    #expect(rig.reporter.claimHaptic(for: first) == false)

    // The next heart is its own moment.
    rig.reporter.advanceNotice()
    rig.reporter.record(trackId: "waves", finishedAt: Self.morning)
    await rig.reporter.flush()
    guard let second = rig.reporter.notice else {
      Issue.record("expected a second notice")
      return
    }
    #expect(rig.reporter.claimHaptic(for: second))
  }

  @Test("A finished track keeps the day, at the moment it finished")
  func recordsTrackActivity() async {
    let rig = makeRig(suite: "deep.listens.test.activity")
    let finishedAt = Self.morning.addingTimeInterval(-90)

    rig.reporter.record(trackId: "rain", finishedAt: finishedAt)
    await rig.reporter.flush()

    #expect(rig.practice.activities == [PracticeActivity(kind: .track, at: finishedAt)])
  }

  @Test("Flushes never overlap: each listen is sent once, one request at a time")
  func flushIsSerial() async {
    let rig = makeRig(suite: "deep.listens.test.serial")
    rig.server.suspends = true

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    rig.reporter.record(trackId: "waves", finishedAt: Self.morning)
    rig.reporter.record(trackId: "wind", finishedAt: Self.morning)
    async let first: Void = rig.reporter.flush()
    async let second: Void = rig.reporter.flush()
    _ = await (first, second)

    #expect(rig.server.maxInFlight == 1)
    #expect(rig.server.calls.map(\.trackId) == ["rain", "waves", "wind"])
    #expect(rig.reporter.hasPending == false)
  }

  @Test("A reset mid-request drops the signed-out account's answer")
  func resetDropsInFlightAnswer() async {
    let rig = makeRig(suite: "deep.listens.test.reset")
    rig.server.suspends = true

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    let flush = Task { await rig.reporter.flush() }
    while rig.server.calls.isEmpty { await Task.yield() }
    rig.reporter.reset()
    await flush.value

    #expect(rig.grants.value.isEmpty)
    #expect(rig.reporter.notice == nil)
    #expect(rig.reporter.hasPending == false)
  }

  // MARK: - Notices

  @Test("An earned heart says +1 heart and announces it")
  func earnedNotice() async {
    let rig = makeRig(suite: "deep.listens.test.earned")
    rig.server.replies = [.outcome(.granted(earned: 1))]

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    await rig.reporter.flush()

    #expect(rig.reporter.notice?.kind == .earned)
    #expect(rig.announcements.value.count == 1)
    #expect(rig.grants.value.count == 1)

    rig.reporter.advanceNotice()
    #expect(rig.reporter.notice == nil)
  }

  @Test("The day's last heart says +1 heart, then that today's are all in")
  func thirdListenCompletesTheDay() async {
    let rig = makeRig(suite: "deep.listens.test.third")
    rig.server.replies = [.outcome(.granted(earned: 3))]

    rig.reporter.record(trackId: "wind", finishedAt: Self.morning)
    await rig.reporter.flush()

    #expect(rig.reporter.notice?.kind == .earned)
    rig.reporter.advanceNotice()
    #expect(rig.reporter.notice?.kind == .dayComplete(perDay: 3))
    rig.reporter.advanceNotice()
    #expect(rig.reporter.notice == nil)
    #expect(rig.announcements.value.count == 2)
  }

  @Test("A listen past the day's allowance says today's are in — once a day")
  func kindCapOncePerDay() async {
    let suite = "deep.listens.test.kindcap"
    let rig = makeRig(suite: suite)
    rig.server.replies = [
      .outcome(.capped("kind_cap", earned: 3)),
      .outcome(.capped("kind_cap", earned: 3)),
      .outcome(.capped("kind_cap", earned: 3)),
    ]

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    await rig.reporter.flush()
    #expect(rig.reporter.notice?.kind == .dayComplete(perDay: 3))
    rig.reporter.advanceNotice()

    rig.reporter.record(trackId: "waves", finishedAt: Self.morning)
    await rig.reporter.flush()
    #expect(rig.reporter.notice == nil)

    // The stamp outlives a relaunch.
    let relaunched = makeRig(suite: suite, defaults: rig.defaults, server: rig.server)
    relaunched.reporter.record(trackId: "wind", finishedAt: Self.morning)
    await relaunched.reporter.flush()
    #expect(relaunched.reporter.notice == nil)
    #expect(rig.announcements.value.count + relaunched.announcements.value.count == 1)
  }

  @Test("An old server without the tally still falls back to the 3-a-day rule")
  func kindCapWithoutTally() async {
    let rig = makeRig(suite: "deep.listens.test.notally")
    var outcome = ListenOutcome.capped("kind_cap", earned: 3)
    outcome.tally = nil
    rig.server.replies = [.outcome(outcome)]

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    await rig.reporter.flush()

    #expect(rig.reporter.notice?.kind == .dayComplete(perDay: RewardRules.trackDailyLimit))
  }

  @Test("A repeat of a track already counted today stays silent")
  func duplicateIsSilent() async {
    let rig = makeRig(suite: "deep.listens.test.duplicate")
    rig.server.replies = [.outcome(.capped("duplicate", earned: 1))]

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    await rig.reporter.flush()

    #expect(rig.reporter.notice == nil)
    #expect(rig.announcements.value.isEmpty)
  }

  @Test("Yesterday's listen lands its heart without a word")
  func yesterdayIsSilent() async {
    let rig = makeRig(suite: "deep.listens.test.yesterday")
    rig.server.replies = [.outcome(.granted(earned: 1))]

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning.addingTimeInterval(-24 * 60 * 60))
    await rig.reporter.flush()

    #expect(rig.grants.value.count == 1)
    #expect(rig.reporter.notice == nil)
  }

  @Test("A heart answered long after the track ended lands without a word")
  func lateAnswerIsSilent() async {
    let rig = makeRig(suite: "deep.listens.test.late")
    rig.server.replies = [.failure(APIError.transport("offline")), .outcome(.granted(earned: 1))]

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    await rig.reporter.flush()
    rig.clock.now = Self.morning.addingTimeInterval(11 * 60)
    await rig.reporter.flush()

    #expect(rig.grants.value.count == 1)
    #expect(rig.reporter.notice == nil)
    #expect(rig.announcements.value.isEmpty)
  }

  @Test("Reset clears the queue, the notice, and the day's stamp")
  func resetForgetsEverything() async {
    let rig = makeRig(suite: "deep.listens.test.forget")
    rig.server.replies = [.outcome(.granted(earned: 3)), .failure(APIError.transport("offline"))]

    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    await rig.reporter.flush()
    rig.reporter.record(trackId: "waves", finishedAt: Self.morning)
    await rig.reporter.flush()
    #expect(rig.reporter.hasPending)

    rig.reporter.reset()
    #expect(rig.reporter.hasPending == false)
    #expect(rig.reporter.notice == nil)

    // The next account's day is its own: its last heart is noticed afresh.
    rig.server.replies = [.outcome(.granted(earned: 3))]
    rig.reporter.record(trackId: "wind", finishedAt: Self.morning)
    await rig.reporter.flush()
    rig.reporter.advanceNotice()
    #expect(rig.reporter.notice?.kind == .dayComplete(perDay: 3))
  }

  @Test("flush(timeout:) reports whether anything is still queued")
  func flushWithTimeout() async {
    let rig = makeRig(suite: "deep.listens.test.timeout")
    #expect(await rig.reporter.flush(timeout: .milliseconds(200)))

    rig.server.replies = [.failure(APIError.transport("offline"))]
    rig.reporter.record(trackId: "rain", finishedAt: Self.morning)
    #expect(await rig.reporter.flush(timeout: .milliseconds(200)) == false)

    // The connection is back: the retry lands.
    #expect(await rig.reporter.flush(timeout: .milliseconds(200)))
  }

  @Test("Only 400 and 404 (and an undecodable 2xx) end a listen's retries")
  func finalErrors() {
    #expect(ListenReporter.isFinal(APIError.http(status: 400, code: "bad_request", message: "")))
    #expect(ListenReporter.isFinal(APIError.http(status: 404, code: "track_not_found", message: "")))
    #expect(ListenReporter.isFinal(APIError.decoding("shape")))
    #expect(ListenReporter.isFinal(APIError.http(status: 500, code: "internal", message: "")) == false)
    #expect(ListenReporter.isFinal(APIError.http(status: 429, code: "rate_limited", message: "")) == false)
    #expect(ListenReporter.isFinal(APIError.unauthorized) == false)
    #expect(ListenReporter.isFinal(APIError.transport("offline")) == false)
    #expect(ListenReporter.isFinal(CancellationError()) == false)
  }
}

private extension ListenOutcome {
  static func granted(earned: Int, perDay: Int = 3) -> ListenOutcome {
    ListenOutcome(
      judged: true,
      granted: true,
      cappedBy: nil,
      tally: ListenTally(dayKey: "2027-01-15", earned: earned, perDay: perDay),
      grant: AwardGrant(hearts: 1, sunlight: 1)
    )
  }

  static func capped(_ reason: String, earned: Int, perDay: Int = 3) -> ListenOutcome {
    ListenOutcome(
      judged: true,
      granted: false,
      cappedBy: reason,
      tally: ListenTally(dayKey: "2027-01-15", earned: earned, perDay: perDay),
      grant: AwardGrant(heartsBalance: 100)
    )
  }

  static let stale = ListenOutcome(judged: false, granted: false, cappedBy: nil, tally: nil, grant: nil)
}
