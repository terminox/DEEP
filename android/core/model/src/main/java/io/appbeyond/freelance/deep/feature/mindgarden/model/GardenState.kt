package io.appbeyond.freelance.deep.feature.mindgarden.model

/**
 * A snapshot of the user's Mind Garden practice — today's progress and streak.
 * Drives the home screen's practice card; the plant's growth lives in
 * `GardenStore`, which owns the server-backed sunlight.
 *
 * Ported from Deep/Deep/Features/MindGarden/Models/GardenState.swift. The live
 * projection (iOS `init(practice:)`) is `PracticeJournal.gardenState()`, so
 * this file stays free of the store.
 */
data class GardenState(
  val minutesToday: Int,
  val dailyGoalMinutes: Int,
  /** Consecutive practice days ending today (or yesterday, before today's
   * session — see `PracticeMath.currentStreakDays`). Tracked, but nothing
   * displays it today — the growth card shows sunlight alone. */
  val streakDays: Int,
) {
  /** Fraction of today's goal completed, clamped to 0...1. */
  val progress: Double
    get() {
      if (dailyGoalMinutes <= 0) return 0.0
      return minOf(1.0, minutesToday.toDouble() / dailyGoalMinutes)
    }

  /** Minutes still needed to close today's goal. */
  val minutesRemaining: Int
    get() = maxOf(0, dailyGoalMinutes - minutesToday)

  companion object {
    val sample = GardenState(minutesToday = 7, dailyGoalMinutes = 10, streakDays = 12)

    /** A first-day garden, before any momentum has built. */
    val fresh = GardenState(minutesToday = 0, dailyGoalMinutes = 10, streakDays = 0)

    /** Goal met — the ceiling state. */
    val flourishing = GardenState(minutesToday = 10, dailyGoalMinutes = 10, streakDays = 30)
  }
}
