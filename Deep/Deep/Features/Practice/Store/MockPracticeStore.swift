import Foundation
import Observation

/// In-memory `PracticeStore` fixture for previews and as the environment
/// default. Deliberately not `#if DEBUG`-gated — environment defaults ship in
/// release (mirroring `HeartLedger.sample` and the fallback `SoundPlayer`).
@MainActor
@Observable
final class MockPracticeStore: PracticeStore {
  var completions: [PracticeCompletion]
  var dailyGoalMinutes: Int
  var minutesToday: Int
  var currentStreakDays: Int
  var longestStreakDays: Int
  var isHydrated: Bool
  var hasUnsynced: Bool
  /// Whether today already counts toward the rhythm — decides whether
  /// `continuityTransition()` reads as a return today.
  var practicedToday: Bool
  /// Every activity recorded, newest last — lets tests assert what a producer
  /// marked.
  private(set) var activities: [PracticeActivity] = []

  init(
    completions: [PracticeCompletion] = [],
    dailyGoalMinutes: Int = 10,
    minutesToday: Int = 7,
    currentStreakDays: Int = 12,
    longestStreakDays: Int = 12,
    isHydrated: Bool = true,
    hasUnsynced: Bool = false,
    practicedToday: Bool = false
  ) {
    self.completions = completions
    self.dailyGoalMinutes = dailyGoalMinutes
    self.minutesToday = minutesToday
    self.currentStreakDays = currentStreakDays
    self.longestStreakDays = longestStreakDays
    self.isHydrated = isHydrated
    self.hasUnsynced = hasUnsynced
    self.practicedToday = practicedToday
  }

  /// A first-day journal, before any practice has landed.
  static var fresh: MockPracticeStore {
    MockPracticeStore(minutesToday: 0, currentStreakDays: 0, longestStreakDays: 0)
  }

  func recordCompletion(of session: DeepSession) {
    minutesToday += session.durationMinutes
    markToday()
  }

  func recordActivity(_ kind: PracticeActivity.Kind, at date: Date) {
    activities.append(PracticeActivity(kind: kind, at: date))
    markToday()
  }

  func continuityTransition() -> ContinuityTransition {
    practicedToday
      ? ContinuityTransition(before: max(0, currentStreakDays - 1), after: currentStreakDays)
      : ContinuityTransition(before: currentStreakDays, after: currentStreakDays)
  }

  func refresh() async {}

  func awaitHydration(timeout: Duration) async {}

  func flushPending(timeout: Duration) async -> Bool { !hasUnsynced }

  func reset() {
    completions = []
    activities = []
    minutesToday = 0
    currentStreakDays = 0
    longestStreakDays = 0
    practicedToday = false
    hasUnsynced = false
  }

  /// The first practice of the day extends the run by one.
  private func markToday() {
    guard !practicedToday else { return }
    practicedToday = true
    currentStreakDays += 1
    longestStreakDays = max(longestStreakDays, currentStreakDays)
  }
}
