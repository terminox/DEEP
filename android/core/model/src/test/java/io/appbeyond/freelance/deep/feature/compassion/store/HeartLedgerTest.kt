package io.appbeyond.freelance.deep.feature.compassion.store

import io.appbeyond.freelance.deep.auth.HttpStatusCarrying
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
 * server refuses — the refusal case checking the cause's pooled total too, as
 * the iOS test does.
 *
 * Android adds the week-4 carry-over's regressions (a wallet refresh or an
 * award landing mid-gift, then the gift refused or accepted), which iOS has no
 * test for because it still double-counts.
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
    mock.refusesSpend = true
    val remote = GatedRewardsRemote(mock)
    val ledger = ledger(balance = 5, remote = remote)

    val pooledBefore = ledger.state.value.pool.hearts(cause)

    val sending = launch { ledger.send(2, cause) }
    runCurrent()
    assertEquals(3, ledger.state.value.balance) // Optimistic decrement plays immediately.
    assertEquals(pooledBefore + 2, ledger.state.value.pool.hearts(cause))

    remote.gate.complete(Unit)
    sending.join()
    assertEquals(5, ledger.state.value.balance)
    assertEquals(0, ledger.state.value.heartsGiven)
    assertEquals(0, ledger.heartsGiven(cause))
    assertEquals(pooledBefore, ledger.state.value.pool.hearts(cause))
    assertEquals(HeartLedger.SpendFailure(amount = 2, categoryId = cause), ledger.state.value.spendFailure)
  }

  // MARK: - A refresh mid-gift (the week-4 carry-over)

  private val untouchedWallet = WalletSummary(
    heartsBalance = 5, heartsEarned = 5, heartsGiven = 0, earnedToday = 0, remainingToday = 30,
  )

  @Test
  @DisplayName("A wallet refresh mid-gift, then the gift refused, counts the gift once")
  fun refreshThenRefusalCountsOnce() = runTest {
    val mock = MockRewardsRemote(walletSummary = untouchedWallet)
    mock.refusesSpend = true
    val remote = GatedRewardsRemote(mock)
    val ledger = ledger(balance = 5, remote = remote)

    val sending = launch { ledger.send(2, cause) }
    runCurrent()
    // The garden pull answers while the POST is out: the server has not
    // applied the gift (it is about to refuse it).
    ledger.hydrate(untouchedWallet)
    assertEquals(3, ledger.state.value.balance, "The gift in flight stays subtracted, so nothing flickers back.")
    assertEquals(2, ledger.state.value.heartsGiven)

    remote.gate.complete(Unit)
    sending.join()
    assertEquals(5, ledger.state.value.balance, "Refused once, returned once — never 7.")
    assertEquals(0, ledger.state.value.heartsGiven)
    assertEquals(0, ledger.heartsGiven(cause))
    assertEquals(HeartLedger.SpendFailure(amount = 2, categoryId = cause), ledger.state.value.spendFailure)
  }

  @Test
  @DisplayName("An award's absolutes mid-gift, then the gift refused, count the gift once")
  fun grantThenRefusalCountsOnce() = runTest {
    val mock = MockRewardsRemote(walletSummary = untouchedWallet)
    mock.refusesSpend = true
    val remote = GatedRewardsRemote(mock)
    val ledger = ledger(balance = 5, remote = remote)

    val sending = launch { ledger.send(2, cause) }
    runCurrent()
    // A session's award settles mid-gift: the server's balance is 5 + 1.
    ledger.apply(AwardGrant(hearts = 1, sunlight = 1, plantId = "oak", heartsBalance = 6, heartsEarnedToday = 1))
    assertEquals(4, ledger.state.value.balance)

    remote.gate.complete(Unit)
    sending.join()
    assertEquals(6, ledger.state.value.balance)
    assertEquals(0, ledger.state.value.heartsGiven)
  }

  @Test
  @DisplayName("A refresh that already counted the gift settles on the server's figures once it lands")
  fun refreshIncludingGiftThenSuccess() = runTest {
    val mock = MockRewardsRemote(walletSummary = untouchedWallet)
    val remote = GatedRewardsRemote(mock)
    val ledger = ledger(balance = 5, remote = remote)

    val sending = launch { ledger.send(2, cause) }
    runCurrent()
    // Served after the server committed the gift, so it already counts it.
    ledger.hydrate(untouchedWallet.copy(heartsBalance = 3, heartsGiven = 2, givenByCategory = mapOf(cause to 2)))
    assertEquals(1, ledger.state.value.balance, "Briefly short by the gift until its own answer lands.")

    remote.gate.complete(Unit)
    sending.join()
    assertEquals(3, ledger.state.value.balance)
    assertEquals(2, ledger.state.value.heartsGiven)
    assertEquals(2, ledger.heartsGiven(cause))
    assertNull(ledger.state.value.spendFailure)
  }

  @Test
  @DisplayName("A refresh that already counted the gift, then the gift's answer lost, settles on the re-send")
  fun refreshIncludingGiftThenLostAnswer() = runTest {
    val mock = MockRewardsRemote(walletSummary = untouchedWallet)
    mock.losesSpendAnswer = true // The commit happens; the response never arrives.
    val remote = GatedRewardsRemote(mock)
    val ledger = ledger(balance = 5, remote = remote)

    val sending = launch { ledger.send(2, cause) }
    runCurrent()
    ledger.hydrate(untouchedWallet.copy(heartsBalance = 3, heartsGiven = 2, givenByCategory = mapOf(cause to 2)))

    remote.gate.complete(Unit)
    sending.join()
    assertNull(ledger.state.value.spendFailure, "An unanswered gift is not a refused one.")
    assertTrue(ledger.hasUnconfirmedSpends)

    mock.losesSpendAnswer = false
    ledger.reconcile()
    assertEquals(3, ledger.state.value.balance)
    assertEquals(2, ledger.state.value.heartsGiven)
    assertFalse(ledger.hasUnconfirmedSpends)
    assertEquals(1, mock.spends.size, "The re-send is the same gift, not a second one.")
  }

  // MARK: - An unknown outcome (QA round 1, B3)

  private val wallet110 = WalletSummary(
    heartsBalance = 110, heartsEarned = 110, heartsGiven = 0, earnedToday = 0, remainingToday = 30,
  )

  @Test
  @DisplayName("A gift the server committed but never answered is not reported as refused")
  fun lostAnswerIsNotARefusal() = runTest {
    val mock = MockRewardsRemote(walletSummary = wallet110)
    mock.losesSpendAnswer = true
    val ledger = ledger(balance = 110, remote = mock)
    val pooledBefore = ledger.state.value.pool.hearts("healthcare")

    ledger.send(10, "healthcare")

    assertNull(ledger.state.value.spendFailure, "No \"they're back in your balance\" for a gift that may have landed.")
    assertEquals(100, ledger.state.value.balance, "The hearts stay out, so the member can't give them twice.")
    assertEquals(10, ledger.heartsGiven("healthcare"))
    assertEquals(pooledBefore + 10, ledger.state.value.pool.hearts("healthcare"), "The pool keeps the gift too.")
    assertTrue(ledger.hasUnconfirmedSpends)
    assertEquals(3, mock.spendAttempts.size, "One attempt and two re-sends…")
    assertEquals(1, mock.spendAttempts.toSet().size, "…all under the same idempotency id.")
    assertEquals(1, mock.spends.size, "The server holds exactly one gift.")
  }

  @Test
  @DisplayName("A wallet refresh after a lost answer, then the re-send, lands on the server's figures once")
  fun lostAnswerReconcilesAfterRefresh() = runTest {
    val mock = MockRewardsRemote(walletSummary = wallet110)
    mock.losesSpendAnswer = true
    val ledger = ledger(balance = 110, remote = mock)
    ledger.send(10, "healthcare")
    mock.losesSpendAnswer = false

    // The pull-to-refresh: the server's wallet already counts the gift.
    ledger.hydrate(mock.wallet())
    ledger.reconcile()

    assertEquals(100, ledger.state.value.balance)
    assertEquals(10, ledger.state.value.heartsGiven)
    assertEquals(10, ledger.heartsGiven("healthcare"))
    assertFalse(ledger.hasUnconfirmedSpends)
    assertNull(ledger.state.value.spendFailure)
    assertEquals(1, mock.spends.size)
  }

  @Test
  @DisplayName("A gift that never reached the server is committed by the re-send, once")
  fun unreachedGiftIsCommittedByResend() = runTest {
    val mock = MockRewardsRemote(walletSummary = wallet110)
    mock.failsSpend = true
    val ledger = ledger(balance = 110, remote = mock)
    ledger.send(10, "healthcare")
    assertEquals(100, ledger.state.value.balance)
    assertTrue(mock.spends.isEmpty())

    mock.failsSpend = false
    ledger.reconcile()

    assertEquals(1, mock.spends.size)
    assertEquals(100, ledger.state.value.balance)
    assertEquals(100, mock.walletSummary.heartsBalance)
    assertFalse(ledger.hasUnconfirmedSpends)
  }

  @Test
  @DisplayName("An unconfirmed gift the server then declines rolls back, with the caption")
  fun unconfirmedThenRefusedRollsBack() = runTest {
    val mock = MockRewardsRemote(walletSummary = wallet110)
    mock.failsSpend = true
    val ledger = ledger(balance = 110, remote = mock)
    val pooledBefore = ledger.state.value.pool.hearts("healthcare")
    ledger.send(10, "healthcare")

    mock.failsSpend = false
    mock.refusesSpend = true
    ledger.reconcile()

    assertEquals(110, ledger.state.value.balance)
    assertEquals(0, ledger.heartsGiven("healthcare"))
    assertEquals(pooledBefore, ledger.state.value.pool.hearts("healthcare"))
    assertEquals(HeartLedger.SpendFailure(amount = 10, categoryId = "healthcare"), ledger.state.value.spendFailure)
    assertFalse(ledger.hasUnconfirmedSpends)
  }

  @Test
  @DisplayName("The next send re-sends an unconfirmed gift first, under its own id")
  fun nextSendResendsUnconfirmedFirst() = runTest {
    val mock = MockRewardsRemote(walletSummary = wallet110)
    mock.failsSpend = true
    val ledger = ledger(balance = 110, remote = mock)
    ledger.send(10, "healthcare")
    val firstId = mock.spendAttempts.first()

    mock.failsSpend = false
    ledger.send(5, cause)

    assertEquals(listOf(firstId), mock.spends.take(1).map { it.id })
    assertEquals(listOf(10, 5), mock.spends.map { it.amount })
    assertEquals(95, ledger.state.value.balance)
    assertEquals(95, mock.walletSummary.heartsBalance)
    assertFalse(ledger.hasUnconfirmedSpends)
  }

  @Test
  @DisplayName("Only a 4xx the server answered is a refusal; timeouts, 408, 429 and 5xx are unknown")
  fun refusalClassification() {
    fun status(code: Int) = object : Exception(), HttpStatusCarrying {
      override val status: Int = code
    }
    assertTrue(HeartLedger.isRefusal(status(409)))
    assertTrue(HeartLedger.isRefusal(status(400)))
    assertTrue(HeartLedger.isRefusal(MockRewardsRemote.Refusal()))
    assertFalse(HeartLedger.isRefusal(status(408)))
    assertFalse(HeartLedger.isRefusal(status(429)))
    assertFalse(HeartLedger.isRefusal(status(500)))
    assertFalse(HeartLedger.isRefusal(status(503)))
    assertFalse(HeartLedger.isRefusal(MockRewardsRemote.Failure()))
    assertFalse(HeartLedger.isRefusal(java.net.SocketTimeoutException("timeout")))
  }

  @Test
  @DisplayName("A send to a project moves that project's pooled total with its cause's")
  fun projectSendMovesProjectPool() = runTest {
    val ledger = ledger(balance = 5)
    val before = ledger.state.value.pool

    ledger.send(1, "healthcare", projectId = "health-clinic")

    val after = ledger.state.value.pool
    assertEquals(before.hearts("healthcare") + 1, after.hearts("healthcare"))
    assertEquals(before.projectHearts("health-clinic") + 1, after.projectHearts("health-clinic"))
    assertEquals(before.heartsPooled + 1, after.heartsPooled)
  }

  @Test
  @DisplayName("Signing out forgets the wallet but keeps the community pool")
  fun resetKeepsPool() = runTest {
    val ledger = ledger(balance = 5)
    ledger.send(2, cause)
    val pool = ledger.state.value.pool

    ledger.resetLocalState()

    assertEquals(0, ledger.state.value.balance)
    assertEquals(pool, ledger.state.value.pool)
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
    mock.refusesSpend = true
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
