import Foundation

/// A snapshot of the user's Mind Garden — today's practice progress, the running
/// streak, and the plants growing across the journey. Drives the home screen.
struct GardenState {
  var minutesToday: Int
  var dailyGoalMinutes: Int
  var streakDays: Int
  var stages: [GardenStage]

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
  static let sample = GardenState(
    minutesToday: 7,
    dailyGoalMinutes: 10,
    streakDays: 12,
    stages: GardenStage.journey
  )

  /// A first-day garden, before any momentum has built.
  static let fresh = GardenState(
    minutesToday: 0,
    dailyGoalMinutes: 10,
    streakDays: 0,
    stages: GardenStage.journey
  )
}
