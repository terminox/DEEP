package io.appbeyond.freelance.deep.feature.rewards.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/RewardReceiptTests.swift.
 *
 * The ending ritual's route and copy gates are derived from one frozen
 * receipt, independent of later store reconciliation.
 */
class RewardReceiptTest {

  @Test
  @DisplayName("An unwitnessed day includes continuity")
  fun unwitnessedDayIncludesContinuity() {
    assertTrue(RewardReceipt.sample.showsContinuity)
    assertFalse(RewardReceipt.sample.rewardsAreFull)
  }

  @Test
  @DisplayName("A day already witnessed ends after compassion")
  fun witnessedDayOmitsContinuity() {
    assertFalse(RewardReceipt.laterToday.showsContinuity)
  }

  @Test
  @DisplayName("A rhythm of no days is never shown")
  fun emptyRhythmOmitsContinuity() {
    val receipt = RewardReceipt(
      gardenBefore = null,
      gardenAfter = null,
      sunlightAwarded = 0,
      heartBalanceBefore = 0,
      heartBalanceAfter = 0,
      heartsEarnedTodayBefore = 0,
      heartsEarnedTodayAfter = 0,
      heartsAwarded = 0,
      continuityBefore = 0,
      continuityAfter = 0,
      continuityWitnessedToday = false,
    )

    assertFalse(receipt.showsContinuity)
  }

  @Test
  @DisplayName("A capped session keeps a settled zero-reward receipt")
  fun cappedReceipt() {
    val receipt = RewardReceipt.capped

    assertTrue(receipt.rewardsAreFull)
    assertEquals(receipt.gardenBefore, receipt.gardenAfter)
    assertEquals(receipt.heartBalanceBefore, receipt.heartBalanceAfter)
  }

  @Test
  @DisplayName("An unavailable garden is represented without inventing progress")
  fun missingGarden() {
    val receipt = RewardReceipt.catchingUp

    assertTrue(receipt.gardenIsCatchingUp)
    assertNull(receipt.gardenBefore)
    assertNull(receipt.gardenAfter)
  }

  @Test
  @DisplayName("Crossing a plant threshold preserves both animation endpoints")
  fun evolutionEndpoints() {
    val receipt = RewardReceipt.evolving

    assertEquals(0, receipt.gardenBefore?.stageIndex)
    assertEquals(1, receipt.gardenAfter?.stageIndex)
    assertEquals(1, receipt.sunlightAwarded)
  }

  @Test
  @DisplayName("A pause night witnesses the rhythm without moving it")
  fun pauseNightWitnessesRhythm() {
    val receipt = RewardReceipt.pauseNight

    assertTrue(receipt.showsContinuity)
    assertEquals(receipt.continuityBefore, receipt.continuityAfter)
    assertEquals(6, receipt.heartsAwarded)
    assertEquals(6, receipt.sunlightAwarded)
  }
}
