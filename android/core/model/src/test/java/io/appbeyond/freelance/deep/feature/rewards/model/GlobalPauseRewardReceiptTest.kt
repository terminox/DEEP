package io.appbeyond.freelance.deep.feature.rewards.model

import io.appbeyond.freelance.deep.feature.globalpause.model.GlobalPauseRewardSnapshot
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenGrowth
import io.appbeyond.freelance.deep.feature.practice.model.ContinuityTransition
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/GlobalPauseRewardReceiptTests.swift.
 *
 * A Global Pause night folds two server-settled grants — attendance and a
 * first peace message — onto the snapshot taken when the meditation ended,
 * and reads the rhythm from the journal once the claim has settled.
 */
class GlobalPauseRewardReceiptTest {

  private val attendance = AwardGrant(hearts = 5, sunlight = 5, plantId = "oak")
  private val message = AwardGrant(hearts = 1, sunlight = 1, plantId = "oak")

  private fun receipt(
    awards: List<AwardGrant>,
    before: GlobalPauseRewardSnapshot = GlobalPauseRewardSnapshot.sample,
    continuity: ContinuityTransition = ContinuityTransition(before = 7, after = 7),
    continuityKnown: Boolean = true,
    attendanceMissed: Boolean = false,
    attendancePending: Boolean = false,
  ): RewardReceipt {
    val hearts = awards.sumOf { it.hearts }
    val sunlight = awards.sumOf { it.sunlight }
    return RewardReceipt.pauseNight(
      before = before,
      awards = awards,
      gardenAfter = before.garden?.let { GardenGrowth(plant = it.plant, sunlight = it.sunlight + sunlight) },
      heartBalanceAfter = before.heartBalance + hearts,
      heartsEarnedTodayAfter = before.heartsEarnedToday + hearts,
      continuity = continuity,
      continuityKnown = continuityKnown,
      attendanceMissed = attendanceMissed,
      attendancePending = attendancePending,
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
    assertFalse(receipt.explainsMissedAttendance)
  }

  @Test
  @DisplayName("A pause as the day's first practice moves the rhythm on by one")
  fun pauseAsFirstPracticeOfTheDay() {
    val receipt = receipt(listOf(attendance), continuity = ContinuityTransition(before = 7, after = 8))

    assertEquals(7, receipt.continuityBefore)
    assertEquals(8, receipt.continuityAfter)
    assertTrue(receipt.returnedToday)
    assertTrue(receipt.showsContinuity)
  }

  @Test
  @DisplayName("A pause after an earlier practice today witnesses the rhythm")
  fun pauseAfterAnEarlierPractice() {
    val receipt = receipt(listOf(attendance))

    assertEquals(receipt.continuityBefore, receipt.continuityAfter)
    assertFalse(receipt.returnedToday)
    assertTrue(receipt.showsContinuity)
  }

  @Test
  @DisplayName("A rhythm an earlier practice already witnessed rests")
  fun continuityRestsWhenAlreadyWitnessed() {
    val receipt = receipt(listOf(attendance), before = GlobalPauseRewardSnapshot.rhythmWitnessed)

    assertFalse(receipt.showsContinuity)
  }

  @Test
  @DisplayName("A rhythm that can't be trusted hides the beat rather than guess")
  fun unknownContinuityRests() {
    val receipt = receipt(
      listOf(attendance),
      continuity = ContinuityTransition(before = 0, after = 1),
      continuityKnown = false,
    )

    assertFalse(receipt.showsContinuity)
  }

  @Test
  @DisplayName("A missed night with no hearts explains why")
  fun missedNightExplains() {
    val receipt = receipt(emptyList(), attendanceMissed = true)

    assertTrue(receipt.attendanceMissed)
    assertTrue(receipt.explainsMissedAttendance)
  }

  @Test
  @DisplayName("An unanswered claim neither promises hearts nor calls the day full")
  fun pendingClaimRests() {
    val receipt = receipt(emptyList(), attendancePending = true)

    assertTrue(receipt.awaitsAttendanceAward)
    assertFalse(receipt.explainsMissedAttendance)
    // Whether tonight keeps the day isn't known yet — the beat rests rather
    // than show N → N.
    assertFalse(receipt.continuityKnown)
    assertFalse(receipt.showsContinuity)
  }

  @Test
  @DisplayName("An unanswered claim beside a message heart shows the heart")
  fun pendingClaimWithMessageAward() {
    val receipt = receipt(listOf(message), attendancePending = true)

    assertEquals(1, receipt.heartsAwarded)
    assertFalse(receipt.awaitsAttendanceAward)
    assertFalse(receipt.showsContinuity)
  }

  @Test
  @DisplayName("An answered claim leaves the rhythm to the journal")
  fun answeredClaimKeepsContinuity() {
    val receipt = receipt(listOf(attendance), continuity = ContinuityTransition(before = 7, after = 8))

    assertFalse(receipt.awaitsAttendanceAward)
    assertTrue(receipt.showsContinuity)
  }

  @Test
  @DisplayName("A missed night whose message still earned shows the heart, not the reason")
  fun missedNightWithMessageAward() {
    val receipt = receipt(listOf(message), attendanceMissed = true)

    assertEquals(1, receipt.heartsAwarded)
    assertFalse(receipt.explainsMissedAttendance)
  }
}
