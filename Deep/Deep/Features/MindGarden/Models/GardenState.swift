import Foundation

/// A snapshot of the user's Mind Garden — today's practice progress and the
/// oak's growth toward its next form. Drives the home screen.
struct GardenState {
  var minutesToday: Int
  var dailyGoalMinutes: Int
  var growth: GardenGrowth
  /// Consecutive practice days ending today (or yesterday, before today's
  /// session — see `PracticeMath.currentStreakDays`).
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
  /// Growth is sample data until growth points persist.
  @MainActor
  init(practice: any PracticeStore) {
    self.init(
      minutesToday: practice.minutesToday,
      dailyGoalMinutes: practice.dailyGoalMinutes,
      growth: .sample,
      streakDays: practice.currentStreakDays
    )
  }

  static let sample = GardenState(
    minutesToday: 7,
    dailyGoalMinutes: 10,
    growth: .sample,
    streakDays: 12
  )

  /// A first-day garden, before any momentum has built.
  static let fresh = GardenState(
    minutesToday: 0,
    dailyGoalMinutes: 10,
    growth: .sprouting,
    streakDays: 0
  )

  /// Goal met and the oak fully evolved — the ceiling state.
  static let flourishing = GardenState(
    minutesToday: 10,
    dailyGoalMinutes: 10,
    growth: .fullyGrown,
    streakDays: 30
  )
}
