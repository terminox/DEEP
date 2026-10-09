import Testing
import Foundation
@testable import Deep

/// `PracticeRemote` that always throws — simulates being offline, so
/// completions stay queued as unsynced.
@MainActor
private final class FailingPracticeRemote: PracticeRemote {
  struct RemoteFailure: Error {}

  func upload(_ completions: [PracticeCompletion]) async throws -> PracticeSyncResult {
    throw RemoteFailure()
  }

  func fetchAll() async throws -> PracticeLog {
    throw RemoteFailure()
  }
}

/// `PracticeRemote` whose calls park until the test opens the gate — the
/// window in which an account can be signed out under an in-flight sync.
/// Once opened, later calls pass straight through.
@MainActor
private final class GatedPracticeRemote: PracticeRemote {
  var log = PracticeLog(completions: [])
  var awards: AwardGrant?
  private var isGated = true
  private var parked: [CheckedContinuation<Void, Never>] = []
  var parkedCount: Int { parked.count }

  func upload(_ completions: [PracticeCompletion]) async throws -> PracticeSyncResult {
    await park()
    return PracticeSyncResult(synced: completions.map(\.id), awards: awards)
  }

  func fetchAll() async throws -> PracticeLog {
    await park()
    return log
  }

  private func park() async {
    guard isGated else { return }
    await withCheckedContinuation { parked.append($0) }
  }

  func releaseAll() {
    isGated = false
    let waiting = parked
    parked = []
    waiting.forEach { $0.resume() }
  }

  /// Polls until a call has parked (bounded, so a broken test fails).
  func waitUntilParked() async {
    for _ in 0..<200 where parked.isEmpty {
      try? await Task.sleep(for: .milliseconds(5))
    }
  }
}

/// `PracticeRemote` that records what it was asked to upload, optionally
/// awards, and hands back a canned server log for `fetchAll`.
@MainActor
private final class RecordingPracticeRemote: PracticeRemote {
  private(set) var uploadedBatches: [[PracticeCompletion]] = []
  var canned: [PracticeCompletion] = []
  /// The server's activity days; nil plays an older server without the field.
  var activityDays: [String]?
  /// Riding every accepted upload, when set — exercises the award sink.
  var awards: AwardGrant?
  private(set) var fetchCount = 0

  func upload(_ completions: [PracticeCompletion]) async throws -> PracticeSyncResult {
    uploadedBatches.append(completions)
    return PracticeSyncResult(synced: completions.map(\.id), awards: awards)
  }

  func fetchAll() async throws -> PracticeLog {
    fetchCount += 1
    return PracticeLog(completions: canned, activityDays: activityDays)
  }
}

/// `PracticeDefaultsStore` reads/writes one JSON blob under this key. The
/// key is private on the store, so tests that need to pre-seed a suite
/// mirror it here rather than reaching into the type.
@MainActor
struct PracticeDefaultsStoreTests {
  private static let journalKey = "deep.practice.journal"

  private static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Bangkok")!
    return calendar
  }()

  private static let now = date(year: 2026, month: 7, day: 23, hour: 12)

  private static func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    return calendar.date(from: components)!
  }

  /// A fresh, empty `UserDefaults` suite scoped to one test, with its name
  /// returned so the caller can tear it down.
  private static func makeSuite() -> (defaults: UserDefaults, name: String) {
    let name = "DeepTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return (defaults, name)
  }

  /// Matches `PracticeDefaultsStore`'s private persisted shape structurally,
  /// so a test can seed a suite as if an earlier launch had already written
  /// to it.
  private struct SeedState: Codable {
    var completions: [PracticeCompletion]
    var dailyGoalMinutes: Int = 10
  }

  private static func seed(_ completions: [PracticeCompletion], in defaults: UserDefaults) {
    let data = try! JSONEncoder().encode(SeedState(completions: completions))
    defaults.set(data, forKey: journalKey)
  }

  private static func session(cycles: Int = 1) -> DeepSession {
    DeepSession(title: "Balancing breath", tagline: "", inhale: 4, exhale: 6, cycles: cycles)
  }

  // MARK: - Persistence

  @Test
  func recordPersistsAcrossASecondStoreInstance() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let store1 = PracticeDefaultsStore(
      defaults: defaults, remote: MockPracticeRemote(), calendar: Self.calendar, now: { Self.now }
    )
    store1.recordCompletion(of: Self.session())

    let store2 = PracticeDefaultsStore(
      defaults: defaults, remote: MockPracticeRemote(), calendar: Self.calendar, now: { Self.now }
    )
    #expect(store2.completions.count == 1)
    #expect(store2.completions.first?.title == "Balancing breath")
  }

  // MARK: - Sync

  @Test
  func recordIsUnsyncedThenSyncedAfterAcceptingRefresh() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let remote = RecordingPracticeRemote()
    let store = PracticeDefaultsStore(
      defaults: defaults, remote: remote, calendar: Self.calendar, now: { Self.now }
    )

    store.recordCompletion(of: Self.session())
    #expect(store.completions.first?.isSynced == false)

    await store.refresh()
    #expect(store.completions.first?.isSynced == true)
  }

  @Test
  func offlineEntriesStayUnsyncedButStillCountTowardMinutesToday() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let store = PracticeDefaultsStore(
      defaults: defaults, remote: FailingPracticeRemote(), calendar: Self.calendar, now: { Self.now }
    )

    store.recordCompletion(of: Self.session())
    await store.refresh()

    #expect(store.completions.first?.isSynced == false)
    #expect(store.minutesToday == 1)
  }

  // MARK: - Award sink

  @Test
  func syncForwardsAwardsToSink() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    // Seeded as unsynced, so the refresh's push is the only upload in play —
    // `recordCompletion`'s own background push never races the assertion.
    let pending = PracticeCompletion(
      id: UUID(), title: "Balancing breath", durationSeconds: 300,
      completedAt: Self.now, isSynced: false
    )
    Self.seed([pending], in: defaults)

    let grant = AwardGrant(hearts: 1, sunlight: 1, plantId: "oak", heartsBalance: 7, plantSunlight: 241)
    let remote = RecordingPracticeRemote()
    remote.awards = grant

    let store = PracticeDefaultsStore(
      defaults: defaults, remote: remote, calendar: Self.calendar, now: { Self.now }
    )
    var received: [AwardGrant] = []
    store.awardSink = { received.append($0) }

    await store.refresh()
    #expect(received == [grant])
    #expect(store.completions.first?.isSynced == true)
  }

  @Test
  func syncWithoutAwardsLeavesSinkUntouched() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let pending = PracticeCompletion(
      id: UUID(), title: "Balancing breath", durationSeconds: 300,
      completedAt: Self.now, isSynced: false
    )
    Self.seed([pending], in: defaults)

    let store = PracticeDefaultsStore(
      defaults: defaults, remote: RecordingPracticeRemote(),
      calendar: Self.calendar, now: { Self.now }
    )
    var received: [AwardGrant] = []
    store.awardSink = { received.append($0) }

    await store.refresh()
    #expect(received.isEmpty)
    #expect(store.completions.first?.isSynced == true)
  }

  // MARK: - Pull merge

  @Test
  func pullMergesServerOnlyEntriesByIdWithoutDuplicatingKnownIds() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let knownID = UUID()
    let known = PracticeCompletion(
      id: knownID, title: "Known locally", durationSeconds: 60, completedAt: Self.now, isSynced: true
    )
    Self.seed([known], in: defaults)

    let remote = RecordingPracticeRemote()
    remote.canned = [
      known,
      PracticeCompletion(
        id: UUID(), title: "Server only", durationSeconds: 120, completedAt: Self.now, isSynced: true
      ),
    ]

    let store = PracticeDefaultsStore(
      defaults: defaults, remote: remote, calendar: Self.calendar, now: { Self.now }
    )
    #expect(store.completions.count == 1)

    await store.refresh()
    #expect(store.completions.count == 2)
    #expect(store.completions.filter { $0.id == knownID }.count == 1)
  }

  // MARK: - Reset

  @Test
  func resetEmptiesAndPersists() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let store1 = PracticeDefaultsStore(
      defaults: defaults, remote: MockPracticeRemote(), calendar: Self.calendar, now: { Self.now }
    )
    store1.recordCompletion(of: Self.session())
    #expect(!store1.completions.isEmpty)

    store1.reset()
    #expect(store1.completions.isEmpty)

    let store2 = PracticeDefaultsStore(
      defaults: defaults, remote: MockPracticeRemote(), calendar: Self.calendar, now: { Self.now }
    )
    #expect(store2.completions.isEmpty)
  }

  // MARK: - Persisted format

  @Test("A journal written by an earlier release still decodes, whole")
  func oldFormatBlobDecodes() throws {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    // Exactly the shape the previous release persisted: no activity markers,
    // no server days, no pull stamp. Dates use JSONEncoder's default
    // (seconds since the reference date).
    let id = UUID()
    let completedAt = Self.date(year: 2026, month: 7, day: 22).timeIntervalSinceReferenceDate
    let blob = """
    {"completions":[{"id":"\(id.uuidString)","title":"Balancing breath",\
    "durationSeconds":300,"completedAt":\(completedAt),"isSynced":true}],\
    "dailyGoalMinutes":15}
    """
    defaults.set(try #require(blob.data(using: .utf8)), forKey: Self.journalKey)

    let store = PracticeDefaultsStore(
      defaults: defaults, remote: MockPracticeRemote(), calendar: Self.calendar, now: { Self.now }
    )

    #expect(store.completions.map(\.id) == [id])
    #expect(store.dailyGoalMinutes == 15)
    #expect(store.currentStreakDays == 1)
    // Never pulled under the new format — not hydrated until the next pull.
    #expect(store.isHydrated == false)
  }

  // MARK: - Activity markers

  @Test("A track-only day keeps the rhythm, persists, and dedupes")
  func activityMarkersCountPersistAndDedupe() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let yesterday = PracticeCompletion(
      id: UUID(), title: "Balancing breath", durationSeconds: 300,
      completedAt: Self.date(year: 2026, month: 7, day: 22), isSynced: true
    )
    Self.seed([yesterday], in: defaults)

    let store = PracticeDefaultsStore(
      defaults: defaults, remote: MockPracticeRemote(), calendar: Self.calendar, now: { Self.now }
    )
    #expect(store.continuityTransition() == ContinuityTransition(before: 1, after: 1))

    store.recordActivity(.track, at: Self.now)
    store.recordActivity(.track, at: Self.now.addingTimeInterval(60))
    #expect(store.continuityTransition() == ContinuityTransition(before: 1, after: 2))
    // Minutes stay DEEP Sessions only.
    #expect(store.minutesToday == 0)

    let relaunched = PracticeDefaultsStore(
      defaults: defaults, remote: MockPracticeRemote(), calendar: Self.calendar, now: { Self.now }
    )
    #expect(relaunched.currentStreakDays == 2)

    relaunched.reset()
    #expect(relaunched.currentStreakDays == 0)
  }

  // MARK: - Hydration

  @Test("A pull hydrates the journal and takes the server's activity days")
  func pullHydratesWithActivityDays() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let remote = RecordingPracticeRemote()
    remote.activityDays = ["2026-07-21", "2026-07-22"]
    let store = PracticeDefaultsStore(
      defaults: defaults, remote: remote, calendar: Self.calendar, now: { Self.now }
    )
    #expect(store.isHydrated == false)

    await store.refresh()
    #expect(store.isHydrated)
    #expect(store.currentStreakDays == 2)

    // An older server omits the field — what we had is kept, not forgotten.
    remote.activityDays = nil
    await store.refresh()
    #expect(store.currentStreakDays == 2)
  }

  @Test("A Thai device's Buddhist calendar still counts the server's activity days")
  func pullCountsActivityDaysUnderBuddhistCalendar() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    var buddhist = Calendar(identifier: .buddhist)
    buddhist.timeZone = TimeZone(identifier: "Asia/Bangkok")!
    buddhist.locale = Locale(identifier: "th_TH")
    let remote = RecordingPracticeRemote()
    remote.activityDays = ["2026-07-21", "2026-07-22"]
    let store = PracticeDefaultsStore(
      defaults: defaults, remote: remote, calendar: buddhist, now: { Self.now }
    )

    await store.refresh()
    #expect(store.currentStreakDays == 2)
    store.recordActivity(.track, at: Self.now)
    #expect(store.continuityTransition() == ContinuityTransition(before: 2, after: 3))
  }

  @Test("Waiting for hydration starts a pull when none is under way")
  func awaitHydrationPulls() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let remote = RecordingPracticeRemote()
    let store = PracticeDefaultsStore(
      defaults: defaults, remote: remote, calendar: Self.calendar, now: { Self.now }
    )

    await store.awaitHydration(timeout: .seconds(2))
    #expect(store.isHydrated)
    #expect(remote.fetchCount == 1)

    // Already hydrated — returns at once without another pull.
    await store.awaitHydration(timeout: .seconds(2))
    #expect(remote.fetchCount == 1)
  }

  @Test("Waiting for hydration gives up after its timeout when offline")
  func awaitHydrationTimesOut() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let store = PracticeDefaultsStore(
      defaults: defaults, remote: FailingPracticeRemote(), calendar: Self.calendar, now: { Self.now }
    )

    await store.awaitHydration(timeout: .milliseconds(300))
    #expect(store.isHydrated == false)
  }

  // MARK: - Account switch

  @Test("A reset during an in-flight pull never resurrects the old account")
  func resetDuringPullDropsTheResult() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let remote = GatedPracticeRemote()
    remote.log = PracticeLog(
      completions: [
        PracticeCompletion(
          id: UUID(), title: "Old account", durationSeconds: 300,
          completedAt: Self.now, isSynced: true
        ),
      ],
      activityDays: ["2026-07-22"]
    )
    let store = PracticeDefaultsStore(
      defaults: defaults, remote: remote, calendar: Self.calendar, now: { Self.now }
    )

    let refresh = Task { await store.refresh() }
    await remote.waitUntilParked()
    #expect(remote.parkedCount == 1)

    store.reset()
    remote.releaseAll()
    await refresh.value

    #expect(store.completions.isEmpty)
    #expect(store.currentStreakDays == 0)
    #expect(store.isHydrated == false)
  }

  @Test("A reset during an in-flight push drops its awards")
  func resetDuringPushDropsTheAwards() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let pending = PracticeCompletion(
      id: UUID(), title: "Balancing breath", durationSeconds: 300,
      completedAt: Self.now, isSynced: false
    )
    Self.seed([pending], in: defaults)

    let remote = GatedPracticeRemote()
    remote.awards = AwardGrant(hearts: 1, sunlight: 1, heartsBalance: 9)
    let store = PracticeDefaultsStore(
      defaults: defaults, remote: remote, calendar: Self.calendar, now: { Self.now }
    )
    var received: [AwardGrant] = []
    store.awardSink = { received.append($0) }

    let refresh = Task { await store.refresh() }
    await remote.waitUntilParked()

    store.reset()
    remote.releaseAll()
    await refresh.value

    #expect(received.isEmpty)
    #expect(store.completions.isEmpty)
  }

  // MARK: - Flush before sign-out

  @Test("Flushing offline reports practice still unsynced")
  func flushPendingOfflineIsFalse() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let pending = PracticeCompletion(
      id: UUID(), title: "Balancing breath", durationSeconds: 300,
      completedAt: Self.now, isSynced: false
    )
    Self.seed([pending], in: defaults)
    let store = PracticeDefaultsStore(
      defaults: defaults, remote: FailingPracticeRemote(), calendar: Self.calendar, now: { Self.now }
    )

    #expect(store.hasUnsynced)
    #expect(await store.flushPending(timeout: .seconds(1)) == false)
    #expect(store.hasUnsynced)
  }

  @Test("Flushing online lands everything")
  func flushPendingOnlineIsTrue() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let pending = PracticeCompletion(
      id: UUID(), title: "Balancing breath", durationSeconds: 300,
      completedAt: Self.now, isSynced: false
    )
    Self.seed([pending], in: defaults)
    let store = PracticeDefaultsStore(
      defaults: defaults, remote: RecordingPracticeRemote(), calendar: Self.calendar, now: { Self.now }
    )

    #expect(await store.flushPending(timeout: .seconds(1)))
    #expect(store.hasUnsynced == false)
  }

  @Test("Flushing gives up at its timeout when the server never answers")
  func flushPendingTimesOut() async {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    let pending = PracticeCompletion(
      id: UUID(), title: "Balancing breath", durationSeconds: 300,
      completedAt: Self.now, isSynced: false
    )
    Self.seed([pending], in: defaults)
    let remote = GatedPracticeRemote()
    let store = PracticeDefaultsStore(
      defaults: defaults, remote: remote, calendar: Self.calendar, now: { Self.now }
    )

    #expect(await store.flushPending(timeout: .milliseconds(200)) == false)
    remote.releaseAll()
  }
}
