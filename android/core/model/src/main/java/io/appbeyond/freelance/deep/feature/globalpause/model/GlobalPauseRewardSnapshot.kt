package io.appbeyond.freelance.deep.feature.globalpause.model

import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenGrowth
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant

/**
 * The books as they stood the moment the meditation ended — frozen before the
 * attendance claim goes out, so the ending ritual can show a true before/after
 * even though the grants land asynchronously behind the reflection.
 *
 * Global Pause awards are server-settled (5 hearts and 5 sunlight for the
 * night, another pair for a first peace message), so unlike a DEEP Session
 * there is no optimistic credit to read back: the "before" has to be kept.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Models/GlobalPauseRewardSnapshot.swift;
 * the receipt fold is `RewardReceipt.pauseNight`.
 */
data class GlobalPauseRewardSnapshot(
  val garden: GardenGrowth?,
  val heartBalance: Int,
  val heartsEarnedToday: Int,
  /** Days of returning as the practice journal has them. A pause night adds no
   * practice day, so this number is witnessed by the ritual, never moved. */
  val continuityDays: Int,
  val continuityWitnessedToday: Boolean,
) {
  companion object {
    /** A mid-journey member arriving at tonight's ending. */
    val sample = GlobalPauseRewardSnapshot(
      garden = GardenGrowth(plant = Plant.oakFixture, sunlight = 240),
      heartBalance = 12,
      heartsEarnedToday = 2,
      continuityDays = 7,
      continuityWitnessedToday = false,
    )

    /** A member whose DEEP Session already witnessed the rhythm today. */
    val rhythmWitnessed = sample.copy(continuityWitnessedToday = true)
  }
}
