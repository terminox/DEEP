import Testing
import Foundation
@testable import Deep

/// `PracticeRemote` that always throws — simulates being offline, so
/// completions stay queued as unsynced.
@MainActor
private final class FailingPracticeRemote: PracticeRemote {
  struct RemoteFailure: Error {}

  func upload(_ completions: [PracticeCompletion]) async throws -> [UUID] {
    throw RemoteFailure()
  }

  func fetchAll() async throws -> [PracticeCompletion] {
    throw RemoteFailure()
  }
}

/// `PracticeRemote` that records what it was asked to upload and hands back
/// a canned server log for `fetchAll`.
@MainActor
private final class RecordingPracticeRemote: PracticeRemote {
  private(set) var uploadedBatches: [[PracticeCompletion]] = []
  var canned: [PracticeCompletion] = []

  func upload(_ completions: [PracticeCompletion]) async throws -> [UUID] {
    uploadedBatches.append(completions)
    return completions.map(\.id)
  }

  func fetchAll() async throws -> [PracticeCompletion] {
    canned
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
}
