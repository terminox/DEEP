import SwiftUI
import Observation

/// `PracticeStore` backed by a single JSON blob in `UserDefaults`, mirroring
/// `OnboardingProgressDefaultsStore`: the whole journal is re-encoded under one
/// key on every mutation, so completions survive relaunch and there are no
/// per-field keys to keep in sync.
///
/// Local-first: a completion is recorded immediately and offered to the
/// backend in the background. If the network is away, the entry simply stays
/// `isSynced == false` and rides along on the next push (next completion,
/// launch, or foreground).
@MainActor
@Observable
final class PracticeDefaultsStore: PracticeStore {
  private static let key = "deep.practice.journal"
  /// How far back local activity markers are kept — the server's
  /// `activityDays` window, so the two always cover the same ground.
  private static let activityRetentionDays = 400

  /// The persisted shape — journal entries plus the gentle daily goal.
  ///
  /// Every field added after the first release MUST be optional (synthesized
  /// `Codable` then decodes a missing key as nil): a blob that fails to decode
  /// falls back to `.fresh`, which would silently wipe an existing member's
  /// whole journal — and their rhythm with it.
  private struct PracticeState: Codable {
    var completions: [PracticeCompletion]
    var dailyGoalMinutes: Int
    /// Days kept by tracks and counted pauses, marked on this install.
    var activities: [PracticeActivity]?
    /// The server's activity days as last pulled ("YYYY-MM-DD").
    var remoteActivityDays: [String]?
    /// When the server's log was last pulled for this account; nil until the
    /// first pull lands — the journal isn't hydrated before then.
    var lastPulledAt: Date?

    static let fresh = PracticeState(completions: [], dailyGoalMinutes: 10)
  }

  private var state: PracticeState {
    didSet { persist() }
  }

  /// Awards settled by a practice sync land here — `AppDependencies` points
  /// this at the shared ingest closure so the ledger and garden reconcile.
  @ObservationIgnored var awardSink: (@MainActor (AwardGrant) -> Void)?

  /// Bumped by `reset()`. A push or pull that started under an earlier
  /// generation belongs to the signed-out account, so its answer is dropped
  /// rather than merged into the next account's journal.
  @ObservationIgnored private var generation = 0
  /// The pull `awaitHydration` started, so waiting twice never pulls twice.
  @ObservationIgnored private var hydrationPull: Task<Void, Never>?

  private let defaults: UserDefaults
  private let remote: any PracticeRemote
  private let calendar: Calendar
  private let now: () -> Date

  init(
    defaults: UserDefaults = .standard,
    remote: any PracticeRemote,
    calendar: Calendar = .current,
    now: @escaping () -> Date = Date.init
  ) {
    self.defaults = defaults
    self.remote = remote
    self.calendar = calendar
    self.now = now
    if let data = defaults.data(forKey: Self.key),
       let decoded = try? JSONDecoder().decode(PracticeState.self, from: data) {
      state = decoded
    } else {
      state = .fresh
    }
  }

  // MARK: - PracticeStore

  var completions: [PracticeCompletion] { state.completions }
  var dailyGoalMinutes: Int { state.dailyGoalMinutes }
  var isHydrated: Bool { state.lastPulledAt != nil }
  var hasUnsynced: Bool { state.completions.contains { !$0.isSynced } }

  var minutesToday: Int {
    PracticeMath.minutesToday(in: state.completions, calendar: calendar, now: now())
  }

  var currentStreakDays: Int {
    PracticeMath.currentStreakDays(days: practiceDays, calendar: calendar, now: now())
  }

  var longestStreakDays: Int {
    PracticeMath.longestStreakDays(days: practiceDays, calendar: calendar)
  }

  func continuityTransition() -> ContinuityTransition {
    PracticeMath.continuityTransition(days: practiceDays, calendar: calendar, now: now())
  }

  /// Every day the rhythm counts: sessions, local markers, and server days.
  private var practiceDays: Set<Date> {
    PracticeMath.practiceDays(
      completions: state.completions,
      activities: state.activities ?? [],
      remoteDays: state.remoteActivityDays ?? [],
      calendar: calendar
    )
  }

  func recordCompletion(of session: DeepSession) {
    let completion = PracticeCompletion(
      id: UUID(),
      title: session.title,
      durationSeconds: Int(session.duration.rounded()),
      completedAt: now(),
      isSynced: false
    )
    // Animated so the garden's numbers settle softly wherever they're shown
    // (the HeartLedger mutation pattern).
    withAnimation(.exhale) {
      state.completions.append(completion)
    }
    Task { await pushUnsynced() }
  }

  func recordActivity(_ kind: PracticeActivity.Kind, at date: Date) {
    var activities = state.activities ?? []
    // One marker per kind per day is all the rhythm reads.
    guard !activities.contains(where: {
      $0.kind == kind && calendar.isDate($0.at, inSameDayAs: date)
    }) else { return }
    activities.append(PracticeActivity(kind: kind, at: date))
    if let cutoff = calendar.date(byAdding: .day, value: -Self.activityRetentionDays, to: now()) {
      activities.removeAll { $0.at < cutoff }
    }
    withAnimation(.exhale) {
      state.activities = activities
    }
  }

  func refresh() async {
    await pushUnsynced()
    await pullRemote()
  }

  func awaitHydration(timeout: Duration) async {
    guard !isHydrated else { return }
    if hydrationPull == nil {
      hydrationPull = Task { [weak self] in
        await self?.pullRemote()
        self?.hydrationPull = nil
      }
    }
    let tick = Duration.milliseconds(100)
    var waited = Duration.zero
    while !isHydrated, waited < timeout {
      try? await Task.sleep(for: tick)
      guard !Task.isCancelled else { return }
      waited += tick
    }
  }

  func flushPending(timeout: Duration) async -> Bool {
    guard hasUnsynced else { return true }
    // Unstructured so a push outliving the timeout still lands (and marks its
    // entries synced) rather than being torn down mid-request.
    let push = Task { await pushUnsynced() }
    let deadline = Task {
      try? await Task.sleep(for: timeout)
    }
    let finished = Task {
      await push.value
      deadline.cancel()
    }
    await deadline.value
    finished.cancel()
    return !hasUnsynced
  }

  func reset() {
    generation += 1
    hydrationPull?.cancel()
    hydrationPull = nil
    state = .fresh
  }

  // MARK: - Sync

  /// Offers every unsynced completion to the backend. Errors are swallowed —
  /// the entries just wait for the next push. Uploads are idempotent by id, so
  /// an overlapping push can never duplicate a session.
  private func pushUnsynced() async {
    let pending = state.completions.filter { !$0.isSynced }
    guard !pending.isEmpty else { return }
    let generation = self.generation
    guard let result = try? await remote.upload(pending),
          generation == self.generation
    else { return }

    let acceptedIDs = Set(result.synced)
    var completions = state.completions
    for index in completions.indices where acceptedIDs.contains(completions[index].id) {
      completions[index].isSynced = true
    }
    state.completions = completions

    // Awards ride the sync: hand the settled grant (absolute figures included)
    // to whoever reconciles the ledger and garden.
    if let awards = result.awards {
      awardSink?(awards)
    }
  }

  /// Merges the server's log into the journal by id — entries recorded on
  /// other installs arrive here — and takes its activity days. Errors are
  /// swallowed; the local journal is already whole.
  private func pullRemote() async {
    let generation = self.generation
    guard let log = try? await remote.fetchAll(),
          generation == self.generation
    else { return }

    var next = state
    let known = Set(next.completions.map(\.id))
    let unseen = log.completions.filter { !known.contains($0.id) }
    if !unseen.isEmpty {
      next.completions = (next.completions + unseen)
        .sorted { $0.completedAt < $1.completedAt }
    }
    // An older server omits the field — keep what we had rather than forget.
    if let days = log.activityDays {
      next.remoteActivityDays = days
    }
    next.lastPulledAt = now()
    state = next
  }

  // MARK: - Persistence

  private func persist() {
    guard let data = try? JSONEncoder().encode(state) else { return }
    defaults.set(data, forKey: Self.key)
  }
}
