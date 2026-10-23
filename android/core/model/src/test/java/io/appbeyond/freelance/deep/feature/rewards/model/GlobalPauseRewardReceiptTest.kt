package io.appbeyond.freelance.deep.feature.rewards.model

import io.appbeyond.freelance.deep.feature.globalpause.model.GlobalPauseRewardSnapshot
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenGrowth
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/GlobalPauseRewardReceiptTests.swift — the receipt
 * maths only; the pause session itself is not part of this module.
 *
 * A Global Pause night folds two server-settled grants — attendance and a
 * first peace message — onto the snapshot taken when the meditation ended.
 */
class GlobalPauseRewardReceiptTest {

  private val attendance = AwardGrant(hearts = 5, sunlight = 5, plantId = "oak")
  private val message = AwardGrant(hearts = 1, sunlight = 1, plantId = "oak")

  private fun receipt(
    awards: List<AwardGrant>,
    before: GlobalPauseRewardSnapshot = GlobalPauseRewardSnapshot.sample,
  ): RewardReceipt {
    val hearts = awards.sumOf { it.hearts }
    val sunlight = awards.sumOf { it.sunlight }
    return RewardReceipt.pauseNight(
      before = before,
      awards = awards,
      gardenAfter = before.garden?.let { GardenGrowth(plant = it.plant, sunlight = it.sunlight + sunlight) },
      heartBalanceAfter = before.heartBalance + hearts,
      heartsEarnedTodayAfter = before.heartsEarnedToday + hearts,
    )
  }

  @Test
  @DisplayName("Attending alone is worth the night's five")
  fun attendanceOnly() {
    val receipt = receipt(listOf(attendance))

    assertEquals(5, receipt.heartsAwarded)
    assertEquals(5, receipt.sunlightAwarded)
    assertEquals(17, receipt.heartBalanceAfter)
  }

  @Test
  @DisplayName("A peace message adds to the same total")
  fun attendanceAndMessage() {
    val receipt = receipt(listOf(attendance, message))

    assertEquals(6, receipt.heartsAwarded)
    assertEquals(6, receipt.sunlightAwarded)
    assertEquals(246, receipt.gardenAfter?.sunlight)
  }

  @Test
  @DisplayName("A night that earned nothing settles rather than promises")
  fun ineligibleNight() {
    val receipt = receipt(emptyList())

    assertTrue(receipt.rewardsAreFull)
    assertEquals(receipt.gardenBefore, receipt.gardenAfter)
    assertEquals(receipt.heartBalanceBefore, receipt.heartBalanceAfter)
  }

  @Test
  @DisplayName("The rhythm is witnessed, never moved by a pause")
  fun continuityIsWitnessed() {
    val receipt = receipt(listOf(attendance))

    assertEquals(receipt.continuityBefore, receipt.continuityAfter)
    assertTrue(receipt.showsContinuity)
  }

  @Test
  @DisplayName("A rhythm an earlier practice already witnessed rests")
  fun continuityRestsWhenAlreadyWitnessed() {
    val receipt = receipt(listOf(attendance), before = GlobalPauseRewardSnapshot.rhythmWitnessed)

    assertFalse(receipt.showsContinuity)
  }
}
