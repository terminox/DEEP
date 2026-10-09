package io.appbeyond.freelance.deep.feature.rewards.model

import io.appbeyond.freelance.deep.feature.globalpause.model.GlobalPauseRewardSnapshot
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenGrowth
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant

/**
 * The reward state one finished practice hands to its ending ritual — a DEEP
 * Session, a Global Pause, anything that closes on the reward beats.
 *
 * Both sides of every change are captured before the first reward screen is
 * shown. Server reconciliation may continue behind the ritual, but it cannot
 * jump a number or replay an animation the member is already watching.
 *
 * Ported from Deep/Deep/Features/Rewards/Models/RewardReceipt.swift, with the
 * pause-night initializer from GlobalPauseRewardSnapshot.swift as [pauseNight].
 */
data class RewardReceipt(
  val gardenBefore: GardenGrowth?,
  val gardenAfter: GardenGrowth?,
  val sunlightAwarded: Int,

  val heartBalanceBefore: Int,
  val heartBalanceAfter: Int,
  val heartsEarnedTodayBefore: Int,
  val heartsEarnedTodayAfter: Int,
  val heartsAwarded: Int,

  val continuityBefore: Int,
  val continuityAfter: Int,
  /** Whether an earlier practice today already witnessed the rhythm — the one
   * day-stamp `ContinuityWitness` keeps for every feature. */
  val continuityWitnessedToday: Boolean,
) {
  /** The rhythm is noticed once a day, and only when there is a rhythm to
   * notice: a member with no returning days behind them meets the beat on the
   * day it first means something. */
  val showsContinuity: Boolean
    get() = !continuityWitnessedToday && continuityAfter > 0

  val gardenIsCatchingUp: Boolean
    get() = gardenAfter == null

  val rewardsAreFull: Boolean
    get() = sunlightAwarded == 0 && heartsAwarded == 0

  companion object {
    /**
     * Folds a pause night's settled grants onto the snapshot the ending froze.
     * The shared award ingest has already handed the grants to the ledger and
     * the garden, so the "after" side is simply what those stores now hold —
     * the grants are only read for what this night actually gave.
     *
     * Continuity is witnessed, not moved: a pause night adds no practice day.
     */
    fun pauseNight(
      before: GlobalPauseRewardSnapshot,
      awards: List<AwardGrant>,
      gardenAfter: GardenGrowth?,
      heartBalanceAfter: Int,
      heartsEarnedTodayAfter: Int,
    ): RewardReceipt = RewardReceipt(
      gardenBefore = before.garden,
      gardenAfter = gardenAfter,
      sunlightAwarded = awards.sumOf { it.sunlight },
      heartBalanceBefore = before.heartBalance,
      heartBalanceAfter = heartBalanceAfter,
      heartsEarnedTodayBefore = before.heartsEarnedToday,
      heartsEarnedTodayAfter = heartsEarnedTodayAfter,
      heartsAwarded = awards.sumOf { it.hearts },
      continuityBefore = before.continuityDays,
      continuityAfter = before.continuityDays,
      continuityWitnessedToday = before.continuityWitnessedToday,
    )

    // Fixtures — previews and tests only; nothing at runtime reads these.

    val sample = RewardReceipt(
      gardenBefore = GardenGrowth(plant = Plant.oakFixture, sunlight = 240),
      gardenAfter = GardenGrowth(plant = Plant.oakFixture, sunlight = 241),
      sunlightAwarded = 1,
      heartBalanceBefore = 12,
      heartBalanceAfter = 13,
      heartsEarnedTodayBefore = 2,
      heartsEarnedTodayAfter = 3,
      heartsAwarded = 1,
      continuityBefore = 6,
      continuityAfter = 7,
      continuityWitnessedToday = false,
    )

    val laterToday = RewardReceipt(
      gardenBefore = GardenGrowth(plant = Plant.sakuraFixture, sunlight = 90),
      gardenAfter = GardenGrowth(plant = Plant.sakuraFixture, sunlight = 91),
      sunlightAwarded = 1,
      heartBalanceBefore = 4,
      heartBalanceAfter = 5,
      heartsEarnedTodayBefore = 1,
      heartsEarnedTodayAfter = 2,
      heartsAwarded = 1,
      continuityBefore = 7,
      continuityAfter = 7,
      continuityWitnessedToday = true,
    )

    val capped = RewardReceipt(
      gardenBefore = GardenGrowth(plant = Plant.oakFixture, sunlight = 240),
      gardenAfter = GardenGrowth(plant = Plant.oakFixture, sunlight = 240),
      sunlightAwarded = 0,
      heartBalanceBefore = 18,
      heartBalanceAfter = 18,
      heartsEarnedTodayBefore = 4,
      heartsEarnedTodayAfter = 4,
      heartsAwarded = 0,
      continuityBefore = 12,
      continuityAfter = 12,
      continuityWitnessedToday = true,
    )

    val evolving = RewardReceipt(
      gardenBefore = GardenGrowth(plant = Plant.oakFixture, sunlight = 199),
      gardenAfter = GardenGrowth(plant = Plant.oakFixture, sunlight = 200),
      sunlightAwarded = 1,
      heartBalanceBefore = 2,
      heartBalanceAfter = 3,
      heartsEarnedTodayBefore = 0,
      heartsEarnedTodayAfter = 1,
      heartsAwarded = 1,
      continuityBefore = 0,
      continuityAfter = 1,
      continuityWitnessedToday = false,
    )

    val catchingUp = RewardReceipt(
      gardenBefore = null,
      gardenAfter = null,
      sunlightAwarded = 0,
      heartBalanceBefore = 2,
      heartBalanceAfter = 3,
      heartsEarnedTodayBefore = 0,
      heartsEarnedTodayAfter = 1,
      heartsAwarded = 1,
      continuityBefore = 0,
      continuityAfter = 1,
      continuityWitnessedToday = false,
    )

    /** A whole Global Pause night: the attendance award and a first peace
     * message, arriving together. The rhythm is witnessed, not incremented — a
     * pause night adds no practice day. */
    val pauseNight = RewardReceipt(
      gardenBefore = GardenGrowth(plant = Plant.oakFixture, sunlight = 240),
      gardenAfter = GardenGrowth(plant = Plant.oakFixture, sunlight = 246),
      sunlightAwarded = 6,
      heartBalanceBefore = 12,
      heartBalanceAfter = 18,
      heartsEarnedTodayBefore = 2,
      heartsEarnedTodayAfter = 8,
      heartsAwarded = 6,
      continuityBefore = 7,
      continuityAfter = 7,
      continuityWitnessedToday = false,
    )

    /** A night the pause award could not be claimed — left early, or already
     * claimed. Nothing is promised and nothing moves. */
    val pauseRested = RewardReceipt(
      gardenBefore = GardenGrowth(plant = Plant.oakFixture, sunlight = 246),
      gardenAfter = GardenGrowth(plant = Plant.oakFixture, sunlight = 246),
      sunlightAwarded = 0,
      heartBalanceBefore = 18,
      heartBalanceAfter = 18,
      heartsEarnedTodayBefore = 8,
      heartsEarnedTodayAfter = 8,
      heartsAwarded = 0,
      continuityBefore = 7,
      continuityAfter = 7,
      continuityWitnessedToday = true,
    )
  }
}
