package io.appbeyond.freelance.deep.feature.rewards.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The fold every award-bearing response goes through (iOS
 * `AwardGrant(outcomes:wallet:plant:)` in RewardsRemote.swift). No iOS suite
 * covers it directly; these pin the rules the ledger and garden depend on.
 */
class AwardGrantTest {

  private val wallet = WalletSummary(
    heartsBalance = 13,
    heartsEarned = 40,
    heartsGiven = 27,
    earnedToday = 3,
    remainingToday = 27,
  )

  private val oakProgress = PlantProgress(plantId = "oak", sunlight = 241, currentStageIndex = 1)

  private fun granted(hearts: Int, sunlight: Int, plantId: String? = "oak") = AwardOutcome(
    kind = AwardKind.SESSION_COMPLETED,
    granted = true,
    heartsGranted = hearts,
    sunlightGranted = sunlight,
    plantId = plantId,
  )

  private fun withheld(cap: AwardCap) = AwardOutcome(kind = AwardKind.SESSION_COMPLETED, granted = false, cappedBy = cap)

  @Test
  @DisplayName("Deltas sum over granted outcomes only")
  fun sumsGrantedOnly() {
    val grant = AwardGrant.fold(
      outcomes = listOf(granted(1, 1), withheld(AwardCap.KIND_CAP), granted(5, 5)),
      wallet = null,
      plant = null,
    )

    assertNotNull(grant)
    assertEquals(6, grant.hearts)
    assertEquals(6, grant.sunlight)
    assertFalse(grant.heartsCapped)
  }

  @Test
  @DisplayName("Only a daily_cap refusal marks the day's hearts as capped")
  fun dailyCapFlag() {
    assertTrue(AwardGrant.fold(listOf(withheld(AwardCap.DAILY_CAP)), null, null)!!.heartsCapped)
    assertFalse(AwardGrant.fold(listOf(withheld(AwardCap.KIND_CAP)), wallet, null)!!.heartsCapped)
    assertFalse(AwardGrant.fold(listOf(withheld(AwardCap.DUPLICATE)), wallet, null)!!.heartsCapped)
  }

  @Test
  @DisplayName("A daily-capped response with no snapshots still folds, granting nothing")
  fun dailyCapAloneIsAGrant() {
    val grant = AwardGrant.fold(listOf(withheld(AwardCap.DAILY_CAP)), wallet = null, plant = null)

    assertEquals(AwardGrant(heartsCapped = true), grant)
  }

  @Test
  @DisplayName("Nothing granted, nothing daily-capped and no snapshots folds to null")
  fun nullWhenNothingToApply() {
    assertNull(AwardGrant.fold(emptyList(), wallet = null, plant = null))
    assertNull(AwardGrant.fold(listOf(withheld(AwardCap.KIND_CAP)), wallet = null, plant = null))
    assertNull(AwardGrant.fold(listOf(withheld(AwardCap.DUPLICATE)), wallet = null, plant = null))
  }

  @Test
  @DisplayName("A wallet alone carries absolutes with zero deltas")
  fun walletAlone() {
    val grant = AwardGrant.fold(emptyList(), wallet = wallet, plant = null)

    assertNotNull(grant)
    assertEquals(0, grant.hearts)
    assertEquals(13, grant.heartsBalance)
    assertEquals(40, grant.heartsEarned)
    assertEquals(27, grant.heartsGiven)
    assertEquals(3, grant.heartsEarnedToday)
    assertEquals(27, grant.heartsRemainingToday)
    assertNull(grant.plantSunlight)
  }

  @Test
  @DisplayName("The plant snapshot's id wins; otherwise the first granted outcome's")
  fun plantIdFallback() {
    val fromSnapshot = AwardGrant.fold(listOf(granted(1, 1, plantId = "sakura")), wallet, oakProgress)
    assertEquals("oak", fromSnapshot?.plantId)
    assertEquals(241, fromSnapshot?.plantSunlight)
    assertEquals(1, fromSnapshot?.plantStageIndex)

    val fromOutcome = AwardGrant.fold(
      listOf(withheld(AwardCap.DUPLICATE).copy(plantId = "lotus"), granted(1, 1, plantId = null), granted(1, 1, "sakura")),
      wallet = null,
      plant = null,
    )
    assertEquals("sakura", fromOutcome?.plantId, "Withheld outcomes never name the credited plant.")
  }

  @Test
  @DisplayName("Wire names round-trip, and unknown ones read as null")
  fun wireNames() {
    assertEquals(AwardCap.DAILY_CAP, AwardCap.fromWire("daily_cap"))
    assertEquals(AwardCap.KIND_CAP, AwardCap.fromWire("kind_cap"))
    assertNull(AwardCap.fromWire("something_new"))
    assertEquals(AwardKind.PAUSE_ATTENDED, AwardKind.fromWire("PAUSE_ATTENDED"))
    assertNull(AwardKind.fromWire(null))
  }
}
