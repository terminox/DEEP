import SwiftUI
import Observation

/// A brief word from the listen reporter for the player chrome: a heart just
/// landed, or today's track hearts are all in.
struct ListenNotice: Equatable, Identifiable {
  enum Kind: Equatable {
    /// This listen earned its heart.
    case earned
    /// Today's track hearts are all in.
    case dayComplete(perDay: Int)
  }

  let id: UUID
  let kind: Kind
}

/// The seam between finished tracks and the hearts they earn. The player
/// chrome depends on this so previews and tests run against
/// `MockListenReporter` (the `SoundPlaying` pattern).
@MainActor
protocol ListenReporting: AnyObject, Observable {
  /// What the player chrome should say right now; nil most of the time.
  var notice: ListenNotice? { get }
  /// Whether any finished track is still waiting to reach the server.
  var hasPending: Bool { get }

  /// Notes a track played through to its end at `finishedAt`: keeps the day
  /// in the member's rhythm, queues the report, and offers it to the server.
  func record(trackId: String, finishedAt: Date)
  /// Offers every queued listen to the server, one at a time.
  func flush() async
  /// Flushes, waiting at most `timeout`. True when nothing is left queued.
  func flush(timeout: Duration) async -> Bool
  /// Forgets the queue and today's notices — log out and account deletion.
  func reset()
  /// Whether a surface showing `notice` should play its haptic: true for the
  /// first to ask, so the heart is felt once however many surfaces show it.
  func claimHaptic(for notice: ListenNotice) -> Bool
}

/// The durable listen report. A finished track is queued in `UserDefaults`
/// before anything touches the network, so a dropped connection, a 5xx or an
/// expired session costs nothing: the queue is retried on launch, sign-in and
/// every return to the foreground until the server answers (or the listen is
/// too old to count — the server's 48h window).
///
/// Reports go out serially and carry their finish time, so a heart earned
/// offline lands on the day it was earned. Every grant is handed to the shared
/// ingest seam so the ledger and garden reconcile.
@MainActor
@Observable
final class ListenReporter: ListenReporting {
  private static let queueKey = "deep.sound.pendingListens"
  private static let dayCompleteKey = "deep.sound.dayCompleteNoticed"
  /// The server places a listen up to 48h back; older ones never count.
  static let retention: TimeInterval = 48 * 60 * 60
  /// A notice only speaks for a listen answered this soon after it finished —
  /// a heart surfacing hours later, mid-something-else, would read as noise.
  static let noticeWindow: TimeInterval = 10 * 60

  /// One finished track waiting for the server.
  struct PendingListen: Codable, Equatable {
    let id: UUID
    let trackId: String
    let completedAt: Date
  }

  private(set) var notice: ListenNotice?
  private(set) var pending: [PendingListen] {
    didSet { persist() }
  }

  var hasPending: Bool {
    let cutoff = now().addingTimeInterval(-Self.retention)
    return pending.contains { $0.completedAt >= cutoff }
  }

  /// Settled grants land here — `AppDependencies` points this at the shared
  /// ingest closure (the `PracticeDefaultsStore.awardSink` pattern).
  @ObservationIgnored var awardSink: (@MainActor (AwardGrant) -> Void)?

  @ObservationIgnored private let report: @MainActor (String, Date) async throws -> ListenOutcome
  @ObservationIgnored private let practiceStore: any PracticeStore
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let calendar: Calendar
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private let noticeDuration: Duration
  @ObservationIgnored private let announce: @MainActor (String) -> Void

  /// The flush under way, so a second caller joins it instead of racing it.
  @ObservationIgnored private var flushTask: Task<Void, Never>?
  /// Set when a flush is asked for mid-flush: the running one goes round once
  /// more so listens queued meanwhile aren't left behind.
  @ObservationIgnored private var flushAgain = false
  /// Bumped by `reset()`. An answer that started under an earlier generation
  /// belongs to the signed-out account and is dropped.
  @ObservationIgnored private var generation = 0
  /// Notices waiting their turn behind the one on screen.
  @ObservationIgnored private var upcoming: [ListenNotice.Kind] = []
  @ObservationIgnored private var expiry: Task<Void, Never>?
  /// The last notice whose haptic was played.
  @ObservationIgnored private var feltNoticeID: UUID?

  init(
    report: @escaping @MainActor (String, Date) async throws -> ListenOutcome,
    practiceStore: any PracticeStore,
    defaults: UserDefaults = .standard,
    calendar: Calendar = .current,
    now: @escaping () -> Date = Date.init,
    noticeDuration: Duration = .seconds(4),
    announce: @escaping @MainActor (String) -> Void = { AccessibilityNotification.Announcement($0).post() }
  ) {
    self.report = report
    self.practiceStore = practiceStore
    self.defaults = defaults
    self.calendar = calendar
    self.now = now
    self.noticeDuration = noticeDuration
    self.announce = announce
    if let data = defaults.data(forKey: Self.queueKey),
       let decoded = try? JSONDecoder().decode([PendingListen].self, from: data) {
      pending = decoded
    } else {
      pending = []
    }
  }

  // MARK: - ListenReporting

  func record(trackId: String, finishedAt: Date) {
    // A track played to its end keeps the day, whatever the server says
    // about the heart.
    practiceStore.recordActivity(.track, at: finishedAt)
    // The server credits a track once per day; a second finish of the same
    // track that day has nothing to earn, so it isn't queued twice.
    let alreadyQueued = pending.contains {
      $0.trackId == trackId && calendar.isDate($0.completedAt, inSameDayAs: finishedAt)
    }
    if !alreadyQueued {
      pending.append(PendingListen(id: UUID(), trackId: trackId, completedAt: finishedAt))
    }
    startFlush()
  }

  func flush() async {
    await startFlush().value
  }

  func flush(timeout: Duration) async -> Bool {
    guard hasPending else { return true }
    // The flush itself is unstructured, so a report outliving the timeout
    // still lands rather than being torn down mid-request.
    let flush = startFlush()
    let deadline = Task {
      try? await Task.sleep(for: timeout)
    }
    let finished = Task {
      await flush.value
      deadline.cancel()
    }
    await deadline.value
    finished.cancel()
    return !hasPending
  }

  func claimHaptic(for notice: ListenNotice) -> Bool {
    guard feltNoticeID != notice.id else { return false }
    feltNoticeID = notice.id
    return true
  }

  func reset() {
    generation += 1
    pending = []
    upcoming = []
    expiry?.cancel()
    expiry = nil
    notice = nil
    defaults.removeObject(forKey: Self.dayCompleteKey)
  }

  // MARK: - Flush

  @discardableResult
  private func startFlush() -> Task<Void, Never> {
    if let flushTask {
      flushAgain = true
      return flushTask
    }
    let task = Task { [weak self] in
      guard let self else { return }
      repeat {
        self.flushAgain = false
        await self.drain()
      } while self.flushAgain && !self.pending.isEmpty
      self.flushTask = nil
    }
    flushTask = task
    return task
  }

  /// Sends the queue oldest first. An answer — any 2xx, or a 400/404 the
  /// listen can never get past — removes the entry; anything that may pass
  /// (offline, a 5xx, an expired session) stops the drain and keeps the rest
  /// for the next flush.
  private func drain() async {
    prune()
    let generation = self.generation
    for entry in pending {
      guard generation == self.generation,
            pending.contains(where: { $0.id == entry.id })
      else { return }
      do {
        let outcome = try await report(entry.trackId, entry.completedAt)
        guard generation == self.generation else { return }
        remove(entry)
        settle(entry, outcome: outcome)
      } catch {
        guard generation == self.generation else { return }
        guard Self.isFinal(error) else { return }
        remove(entry)
      }
    }
  }

  /// Whether a failed report can never succeed, so retrying is pointless.
  static func isFinal(_ error: Error) -> Bool {
    switch error {
    case APIError.http(let status, _, _):
      // 400: the server rejected the report's shape; 404: the track is gone.
      return status == 400 || status == 404
    case APIError.decoding:
      // The server answered 2xx — the listen was received.
      return true
    default:
      return false
    }
  }

  private func remove(_ entry: PendingListen) {
    pending.removeAll { $0.id == entry.id }
  }

  /// Drops listens the server would no longer place.
  private func prune() {
    let cutoff = now().addingTimeInterval(-Self.retention)
    if pending.contains(where: { $0.completedAt < cutoff }) {
      pending.removeAll { $0.completedAt < cutoff }
    }
  }

  // MARK: - Settling

  private func settle(_ entry: PendingListen, outcome: ListenOutcome) {
    if let grant = outcome.grant {
      awardSink?(grant)
    }
    // An unjudged listen (too old to place) has nothing to say.
    guard outcome.judged else { return }

    // Only a listen from today, answered while the member is plausibly still
    // there, gets a word in the chrome.
    let current = now()
    guard calendar.isDate(entry.completedAt, inSameDayAs: current),
          current.timeIntervalSince(entry.completedAt) <= Self.noticeWindow
    else { return }

    let perDay = outcome.tally?.perDay ?? RewardRules.trackDailyLimit
    if outcome.granted {
      present(.earned)
      if outcome.tally?.isComplete == true {
        presentDayComplete(perDay: perDay)
      }
    } else if outcome.cappedBy == "kind_cap" {
      presentDayComplete(perDay: perDay)
    }
    // "duplicate" and "daily_cap" stay silent: nothing new happened.
  }

  /// Today's hearts being in is said once a day, however many listens follow.
  private func presentDayComplete(perDay: Int) {
    let current = now()
    if let noticed = defaults.object(forKey: Self.dayCompleteKey) as? Date,
       calendar.isDate(noticed, inSameDayAs: current) {
      return
    }
    defaults.set(current, forKey: Self.dayCompleteKey)
    present(.dayComplete(perDay: perDay))
  }

  // MARK: - Notices

  private func present(_ kind: ListenNotice.Kind) {
    upcoming.append(kind)
    if notice == nil { advanceNotice() }
  }

  /// Retires the notice on screen and shows the next one waiting, if any.
  /// The expiry timer calls this; tests call it to step through a sequence.
  func advanceNotice() {
    expiry?.cancel()
    expiry = nil
    guard !upcoming.isEmpty else {
      notice = nil
      return
    }
    let kind = upcoming.removeFirst()
    notice = ListenNotice(id: UUID(), kind: kind)
    announce(Self.announcement(for: kind))
    let duration = noticeDuration
    expiry = Task { [weak self] in
      try? await Task.sleep(for: duration)
      guard !Task.isCancelled else { return }
      self?.advanceNotice()
    }
  }

  static func announcement(for kind: ListenNotice.Kind) -> String {
    switch kind {
    case .earned:
      String(localized: "You earned 1 heart for listening", bundle: .app, locale: .app)
    case .dayComplete(let perDay):
      String(localized: "Today's \(perDay) sound hearts are in", bundle: .app, locale: .app)
    }
  }

  // MARK: - Persistence

  private func persist() {
    guard let data = try? JSONEncoder().encode(pending) else { return }
    defaults.set(data, forKey: Self.queueKey)
  }
}

// MARK: - Mock

/// In-memory `ListenReporting` fixture for previews and as the environment
/// default. Deliberately not `#if DEBUG`-gated — environment defaults ship in
/// release (mirroring `MockPracticeStore`).
@MainActor
@Observable
final class MockListenReporter: ListenReporting {
  var notice: ListenNotice?
  var hasPending: Bool
  /// Every listen recorded, newest last.
  private(set) var recorded: [(trackId: String, finishedAt: Date)] = []

  init(notice: ListenNotice.Kind? = nil, hasPending: Bool = false) {
    self.notice = notice.map { ListenNotice(id: UUID(), kind: $0) }
    self.hasPending = hasPending
  }

  func record(trackId: String, finishedAt: Date) {
    recorded.append((trackId, finishedAt))
  }

  func flush() async {}

  func flush(timeout: Duration) async -> Bool { !hasPending }

  func reset() {
    notice = nil
    hasPending = false
    recorded = []
  }

  @ObservationIgnored private var feltNoticeID: UUID?

  func claimHaptic(for notice: ListenNotice) -> Bool {
    guard feltNoticeID != notice.id else { return false }
    feltNoticeID = notice.id
    return true
  }

  /// Showing "+1 heart".
  static var earned: MockListenReporter { MockListenReporter(notice: .earned) }

  /// Showing that today's track hearts are all in.
  static var dayComplete: MockListenReporter {
    MockListenReporter(notice: .dayComplete(perDay: RewardRules.trackDailyLimit))
  }
}

extension EnvironmentValues {
  /// The shared listen reporter. The shell injects the live one; the default
  /// keeps previews hermetic (mirroring `\.practiceStore`).
  @Entry var listenReporter: any ListenReporting = MockListenReporter()
}
