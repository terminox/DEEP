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

  init(
    completions: [PracticeCompletion] = [],
    dailyGoalMinutes: Int = 10,
    minutesToday: Int = 7,
    currentStreakDays: Int = 12,
    longestStreakDays: Int = 12
  ) {
    self.completions = completions
    self.dailyGoalMinutes = dailyGoalMinutes
    self.minutesToday = minutesToday
    self.currentStreakDays = currentStreakDays
    self.longestStreakDays = longestStreakDays
  }

  /// A first-day journal, before any practice has landed.
  static var fresh: MockPracticeStore {
    MockPracticeStore(minutesToday: 0, currentStreakDays: 0, longestStreakDays: 0)
  }

  func recordCompletion(of session: DeepSession) {
    minutesToday += session.durationMinutes
  }

  func refresh() async {}

  func reset() {
    completions = []
    minutesToday = 0
    currentStreakDays = 0
    longestStreakDays = 0
  }
}
