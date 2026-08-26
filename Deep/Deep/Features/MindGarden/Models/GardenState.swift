import Foundation

/// A snapshot of the user's Mind Garden practice — today's progress and streak.
/// Drives the home screen's practice card; the plant's growth lives in
/// `GardenStore`, which owns the server-backed sunlight.
struct GardenState {
  var minutesToday: Int
  var dailyGoalMinutes: Int
  /// Consecutive practice days ending today (or yesterday, before today's
  /// session — see `PracticeMath.currentStreakDays`). Tracked, but nothing
  /// displays it today — the growth card shows sunlight alone.
  var streakDays: Int

  /// Fraction of today's goal completed, clamped to 0...1.
  var progress: Double {
    guard dailyGoalMinutes > 0 else { return 0 }
    return min(1, Double(minutesToday) / Double(dailyGoalMinutes))
  }

  /// Minutes still needed to close today's goal.
  var minutesRemaining: Int {
    max(0, dailyGoalMinutes - minutesToday)
  }
}

extension GardenState {
  /// The live garden — a projection of the shared practice journal, re-derived
  /// wherever it's read so a finished session shows up everywhere at once.
  @MainActor
  init(practice: any PracticeStore) {
    self.init(
      minutesToday: practice.minutesToday,
      dailyGoalMinutes: practice.dailyGoalMinutes,
      streakDays: practice.currentStreakDays
    )
  }

  static let sample = GardenState(
    minutesToday: 7,
    dailyGoalMinutes: 10,
    streakDays: 12
  )

  /// A first-day garden, before any momentum has built.
  static let fresh = GardenState(
    minutesToday: 0,
    dailyGoalMinutes: 10,
    streakDays: 0
  )

  /// Goal met — the ceiling state (pair with `GardenStore.flourishing`).
  static let flourishing = GardenState(
    minutesToday: 10,
    dailyGoalMinutes: 10,
    streakDays: 30
  )
}
