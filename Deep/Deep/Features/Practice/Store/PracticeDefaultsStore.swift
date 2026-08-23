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

  /// The persisted shape — journal entries plus the gentle daily goal.
  private struct PracticeState: Codable {
    var completions: [PracticeCompletion]
    var dailyGoalMinutes: Int

    static let fresh = PracticeState(completions: [], dailyGoalMinutes: 10)
  }

  private var state: PracticeState {
    didSet { persist() }
  }

  /// Awards settled by a practice sync land here — `AppDependencies` points
  /// this at the shared ingest closure so the ledger and garden reconcile.
  @ObservationIgnored var awardSink: (@MainActor (AwardGrant) -> Void)?

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

  var minutesToday: Int {
    PracticeMath.minutesToday(in: state.completions, calendar: calendar, now: now())
  }

  var currentStreakDays: Int {
    PracticeMath.currentStreakDays(in: state.completions, calendar: calendar, now: now())
  }

  var longestStreakDays: Int {
    PracticeMath.longestStreakDays(in: state.completions, calendar: calendar)
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

  func refresh() async {
    await pushUnsynced()
    await pullRemote()
  }

  func reset() {
    state = .fresh
  }

  // MARK: - Sync

  /// Offers every unsynced completion to the backend. Errors are swallowed —
  /// the entries just wait for the next push. Uploads are idempotent by id, so
  /// an overlapping push can never duplicate a session.
  private func pushUnsynced() async {
    let pending = state.completions.filter { !$0.isSynced }
    guard !pending.isEmpty else { return }
    guard let result = try? await remote.upload(pending) else { return }

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
  /// other installs arrive here. Errors are swallowed; the local journal is
  /// already whole.
  private func pullRemote() async {
    guard let fetched = try? await remote.fetchAll() else { return }
    let known = Set(state.completions.map(\.id))
    let unseen = fetched.filter { !known.contains($0.id) }
    guard !unseen.isEmpty else { return }
    state.completions = (state.completions + unseen)
      .sorted { $0.completedAt < $1.completedAt }
  }

  // MARK: - Persistence

  private func persist() {
    guard let data = try? JSONEncoder().encode(state) else { return }
    defaults.set(data, forKey: Self.key)
  }
}
