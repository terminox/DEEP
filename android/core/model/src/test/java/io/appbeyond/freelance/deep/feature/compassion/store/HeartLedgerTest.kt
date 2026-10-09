package io.appbeyond.freelance.deep.feature.compassion.store

import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.feature.rewards.model.WalletSummary
import io.appbeyond.freelance.deep.feature.rewards.store.GatedRewardsRemote
import io.appbeyond.freelance.deep.feature.rewards.store.MockRewardsRemote
import io.appbeyond.freelance.deep.feature.rewards.store.RewardsRemote
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.UUID
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/HeartLedgerTests.swift.
 *
 * The ledger's three behaviours that can't be reached by hand: the daily earn
 * ceiling (thirty finished sessions), the absolute reconcile that keeps
 * optimistic credits from double-counting, and the spend rollback when the
 * server refuses. The iOS refusal test also checks the cause's pooled total;
 * that half arrives with the Compassion catalog in week 5.
 */
@OptIn(ExperimentalCoroutinesApi::class) // runCurrent, to park a spend mid-flight.
class HeartLedgerTest {

  private val ceiling = HeartLedger.dailyEarnCeiling

  private val zone: ZoneId = ZoneId.of("Asia/Bangkok")

  private val now: Instant = ZonedDateTime.of(2026, 7, 23, 12, 0, 0, 0, zone).toInstant()

  private val clock: Clock = Clock.fixed(now, zone)

  private val cause = "peace"

  private fun ledger(
    balance: Int,
    heartsEarnedToday: Int = 0,
    remote: RewardsRemote? = null,
    clock: Clock = this.clock,
  ) = HeartLedger(
    remote = remote,
    clock = clock,
    zone = zone,
    balance = balance,
    heartsEarnedToday = heartsEarnedToday,
  )

  // MARK: - The earn predictor

  @Test
  @DisplayName("A fresh day starts empty and open")
  fun freshDay() {
    val ledger = ledger(balance = 0)

    assertEquals(0, ledger.heartsEarnedToday)
    assertEquals(ceiling, ledger.heartsRemainingToday)
    assertFalse(ledger.isTodayFull)
  }

  @Test
  @DisplayName("Earning credits the balance and today's tally together")
  fun earnCredits() {
    val ledger = ledger(balance = 10)

    assertEquals(1, ledger.earn())
    assertEquals(11, ledger.state.value.balance)
    assertEquals(1, ledger.heartsEarnedToday)
    assertEquals(ceiling - 1, ledger.heartsRemainingToday)
  }

  @Test
  @DisplayName("A day fills at the ceiling and no further")
  fun fillsToCeiling() {
    val ledger = ledger(balance = 0)

    repeat(ceiling) { ledger.earn() }

    assertEquals(ceiling, ledger.state.value.balance)
    assertEquals(ceiling, ledger.heartsEarnedToday)
    assertTrue(ledger.isTodayFull)

    // The session past the ceiling still counts as practice, but hands over no
    // heart — the completion beat reads this to decide what it promises.
    assertEquals(0, ledger.earn())
    assertEquals(ceiling, ledger.state.value.balance)
    assertEquals(ceiling, ledger.heartsEarnedToday)
  }

  @Test
  @DisplayName("A batch earn is clamped to what the day has left")
  fun batchIsClamped() {
    val ledger = ledger(balance = 0, heartsEarnedToday = ceiling - 2)

    assertEquals(2, ledger.earn(5))
    assertEquals(2, ledger.state.value.balance)
    assertTrue(ledger.isTodayFull)
  }

  @Test
  @DisplayName("A tally passed in above the ceiling is clamped, never negative remaining")
  fun initClampsTally() {
    val ledger = ledger(balance = 0, heartsEarnedToday = ceiling + 40)

    assertEquals(ceiling, ledger.heartsEarnedToday)
    assertEquals(0, ledger.heartsRemainingToday)
  }

  @Test
  @DisplayName("Yesterday's full tally lets go once the day turns")
  fun tallyRollsOverAtMidnight() {
    var instant = now
    val ticking = object : Clock() {
      override fun getZone(): ZoneId = zone
      override fun withZone(zone: ZoneId?): Clock = this
      override fun instant(): Instant = instant
    }
    val ledger = ledger(balance = 0, heartsEarnedToday = ceiling, clock = ticking)
    assertTrue(ledger.isTodayFull)

    instant = ZonedDateTime.of(2026, 7, 24, 0, 1, 0, 0, zone).toInstant()

    assertEquals(0, ledger.heartsEarnedToday)
    assertEquals(1, ledger.earn())
    assertEquals(1, ledger.heartsEarnedToday)
  }

  // MARK: - Hydration & absolute reconcile

  @Test
  @DisplayName("Hydrating adopts the server's absolute wallet figures")
  fun hydrateSetsAbsolutes() {
    val ledger = ledger(balance = 0)

    ledger.hydrate(
      WalletSummary(
        heartsBalance = 42,
        heartsEarned = 60,
        heartsGiven = 18,
        earnedToday = 3,
        remainingToday = 27,
        dailyCap = 30,
        givenByCategory = mapOf("peace" to 18),
      )
    )

    assertEquals(42, ledger.state.value.balance)
    assertEquals(18, ledger.state.value.heartsGiven)
    assertEquals(3, ledger.heartsEarnedToday)
    assertEquals(ceiling - 3, ledger.heartsRemainingToday)
    assertEquals(18, ledger.heartsGiven("peace"))
  }

  @Test
  @DisplayName("Applying a grant with absolutes reconciles an optimistic earn, never doubles it")
  fun applyReconcilesAbsolutes() {
    val ledger = ledger(balance = 10)
    ledger.earn() // Optimistic +1 the completion beat already played.

    // The practice sync answers with the same award as absolute figures.
    ledger.apply(
      AwardGrant(hearts = 1, sunlight = 1, plantId = "oak", heartsBalance = 11, heartsEarnedToday = 1)
    )

    assertEquals(11, ledger.state.value.balance)
    assertEquals(1, ledger.heartsEarnedToday)
  }

  @Test
  @DisplayName("A grant without snapshots falls back to its deltas")
  fun applyDeltaFallback() {
    val ledger = ledger(balance = 10, heartsEarnedToday = 2)

    ledger.apply(AwardGrant(hearts = 5, sunlight = 5, plantId = "oak"))

    assertEquals(15, ledger.state.value.balance)
    assertEquals(7, ledger.heartsEarnedToday)
  }

  // MARK: - Giving

  @Test
  @DisplayName("Giving a heart spends the balance without touching today's tally")
  fun givingLeavesTodayAlone() = runTest {
    val ledger = ledger(balance = 5, heartsEarnedToday = 3)

    ledger.send(1, cause)

    assertEquals(4, ledger.state.value.balance)
    assertEquals(1, ledger.state.value.heartsGiven)
    assertEquals(3, ledger.heartsEarnedToday)
  }

  @Test
  @DisplayName("A remote-backed send is optimistic, then settles on the server's absolutes")
  fun sendReconcilesWithServer() = runTest {
    val mock = MockRewardsRemote(
      walletSummary = WalletSummary(
        heartsBalance = 5, heartsEarned = 5, heartsGiven = 0, earnedToday = 0,
        remainingToday = 30, dailyCap = 30, givenByCategory = emptyMap(),
      )
    )
    val remote = GatedRewardsRemote(mock)
    val ledger = ledger(balance = 5, remote = remote)

    val sending = launch { ledger.send(2, cause) }
    runCurrent()
    assertEquals(3, ledger.state.value.balance) // Optimistic, before the POST lands.

    remote.gate.complete(Unit)
    sending.join()
    assertEquals(3, ledger.state.value.balance)
    assertEquals(2, ledger.state.value.heartsGiven)
    assertNull(ledger.state.value.spendFailure)
    assertEquals(1, mock.spends.size)
    assertEquals(2, mock.spends.first().amount)
    assertEquals(cause, mock.spends.first().category)
  }

  @Test
  @DisplayName("A refused spend rolls the whole optimistic mutation back")
  fun sendRollsBackOnServerRefusal() = runTest {
    val mock = MockRewardsRemote()
    mock.failsSpend = true
    val remote = GatedRewardsRemote(mock)
    val ledger = ledger(balance = 5, remote = remote)

    val sending = launch { ledger.send(2, cause) }
    runCurrent()
    assertEquals(3, ledger.state.value.balance) // Optimistic decrement plays immediately.

    remote.gate.complete(Unit)
    sending.join()
    assertEquals(5, ledger.state.value.balance)
    assertEquals(0, ledger.state.value.heartsGiven)
    assertEquals(0, ledger.heartsGiven(cause))
    assertEquals(HeartLedger.SpendFailure(amount = 2, categoryId = cause), ledger.state.value.spendFailure)
  }

  @Test
  @DisplayName("Without a remote, sends stay purely local — the fixture behaviour")
  fun sendWithoutRemoteStaysLocal() = runTest {
    val ledger = ledger(balance = 5)

    ledger.send(2, cause)

    assertEquals(3, ledger.state.value.balance)
    assertEquals(2, ledger.state.value.heartsGiven)
  }

  @Test
  @DisplayName("The spent fixture is a full day with nothing left to give")
  fun spentFixture() {
    val ledger = HeartLedger.spent(clock, zone)

    assertFalse(ledger.canGive)
    assertTrue(ledger.isTodayFull)
  }

  // MARK: - Sign-out

  @Test
  @DisplayName("A spend that settles after sign-out is dropped, success or refusal")
  fun lateSpendAfterResetIsDropped() = runTest {
    val mock = MockRewardsRemote()
    mock.failsSpend = true
    val remote = GatedRewardsRemote(mock)
    val ledger = ledger(balance = 5, remote = remote)

    val sending = launch { ledger.send(2, cause) }
    runCurrent()
    ledger.resetLocalState()
    remote.gate.complete(Unit)
    sending.join()

    assertEquals(0, ledger.state.value.balance, "A rollback must not hand the old account's hearts back.")
    assertEquals(0, ledger.state.value.heartsGiven)
    assertNull(ledger.state.value.spendFailure)
  }

  // MARK: - Races (peer review)

  /** Answers each spend from [delegate] only when that call's own gate opens. */
  private class SteppedSpendRemote(
    val delegate: MockRewardsRemote,
  ) : RewardsRemote by delegate {
    val gates = List(4) { CompletableDeferred<Unit>() }
    var started = 0

    override suspend fun spend(id: UUID, amount: Int, category: String, projectId: String?): WalletSummary {
      val call = started++
      gates[call].await()
      return delegate.spend(id, amount, category, projectId)
    }
  }

  @Test
  @DisplayName("Spends go up one at a time, and an older snapshot never erases a newer send")
  fun spendsAreSerialised() = runTest {
    val mock = MockRewardsRemote(
      walletSummary = WalletSummary(
        heartsBalance = 5, heartsEarned = 5, heartsGiven = 0, earnedToday = 0, remainingToday = 30,
      )
    )
    val remote = SteppedSpendRemote(mock)
    val ledger = ledger(balance = 5, remote = remote)

    val first = launch { ledger.send(1, cause) }
    val second = launch { ledger.send(2, cause) }
    runCurrent()
    assertEquals(1, remote.started, "The second spend waits for the first to settle.")
    assertEquals(2, ledger.state.value.balance)

    remote.gates[0].complete(Unit)
    runCurrent()
    assertEquals(2, remote.started)
    assertEquals(2, ledger.state.value.balance, "The first snapshot (balance 4) predates the second send.")
    assertEquals(3, ledger.state.value.heartsGiven)

    remote.gates[1].complete(Unit)
    first.join()
    second.join()
    assertEquals(2, ledger.state.value.balance)
    assertEquals(3, ledger.state.value.heartsGiven)
    assertEquals(3, ledger.heartsGiven(cause))
  }
}
