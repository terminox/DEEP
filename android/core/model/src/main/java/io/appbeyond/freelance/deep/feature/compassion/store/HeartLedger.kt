package io.appbeyond.freelance.deep.feature.compassion.store

import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.feature.rewards.model.RewardRules
import io.appbeyond.freelance.deep.feature.rewards.model.WalletSummary
import io.appbeyond.freelance.deep.feature.rewards.store.RewardsRemote
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

/**
 * The member's hearts: how many they hold, how many they have given and
 * where, and how much of today's earning ceiling is left.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Models/HeartLedger.swift.
 * The day maths reads [clock] in [zone] rather than `Calendar.current`, so the
 * day boundary follows the member's timezone and a test can pin it. Persists
 * nothing (parity): the first garden/wallet fetch hydrates it.
 *
 * Not ported yet: the community side of iOS's ledger — the compassion
 * categories' and projects' pooled `heartsShared` totals, `peopleReached`,
 * `causesSupported`, field reports. Those need the Compassion catalog, which
 * arrives with week 5; until then [send] moves only this member's own books
 * ([State.givenByCategory] is the per-user spread).
 *
 * Every spend is stamped with a generation; one that settles after
 * [resetLocalState] is dropped, so a previous account's wallet never lands on
 * the next one. Spends go to the server one at a time, and a spend's absolute
 * snapshot is only adopted once no other optimistic spend is still waiting,
 * so an older snapshot can never overwrite a newer optimistic send.
 *
 * Known, at iOS parity (not fixed here):
 * - A [hydrate] that lands while a spend is in flight already includes that
 *   spend; if the server then refuses it, the rollback re-adds the amount on
 *   top of the hydrated figures and double-counts until the next hydrate. The
 *   spend UI arrives in week 5 — fix then with pending-delta tracking.
 * - A wallet or grant whose `earnedToday` was computed for yesterday but lands
 *   just after midnight is labelled with today's date (the tally day is taken
 *   from the device clock on arrival), exactly as iOS does.
 */
class HeartLedger(
  private val remote: RewardsRemote?,
  private val clock: Clock,
  private val zone: ZoneId,
  balance: Int = 0,
  heartsGiven: Int = 0,
  heartsEarnedToday: Int = 0,
  givenByCategory: Map<String, Int> = emptyMap(),
) {

  /** A spend the server refused after the optimistic decrement had already
   * played — the rollback's quiet caption reads it. */
  data class SpendFailure(val amount: Int, val categoryId: String)

  data class State(
    /** Hearts the member currently holds. */
    val balance: Int,
    /** Hearts the member has personally given so far. */
    val heartsGiven: Int,
    /** Hearts credited on [tallyDay]. Read through [heartsEarnedOn], which
     * discards it once the day has turned. */
    val earnedTally: Int,
    /** The local day [earnedTally] belongs to. */
    val tallyDay: LocalDate,
    /** Hearts this member has sent, by compassion category id. */
    val givenByCategory: Map<String, Int>,
    /** Set when a spend was rolled back; cleared by the next send or
     * [clearSpendFailure]. */
    val spendFailure: SpendFailure? = null,
  ) {
    /** Whether the member has a heart left to give. */
    val canGive: Boolean get() = balance > 0

    /** Hearts credited on [today] — zero once the tally's day has passed. */
    fun heartsEarnedOn(today: LocalDate): Int = if (tallyDay == today) earnedTally else 0

    /** Hearts [today] can still hand over. */
    fun heartsRemainingOn(today: LocalDate): Int = maxOf(0, dailyEarnCeiling - heartsEarnedOn(today))

    /** Hearts this member has sent to one cause. */
    fun heartsGiven(categoryId: String): Int = givenByCategory[categoryId] ?: 0
  }

  private val _state = MutableStateFlow(
    State(
      balance = balance,
      heartsGiven = heartsGiven,
      earnedTally = minOf(heartsEarnedToday, dailyEarnCeiling),
      tallyDay = today(),
      givenByCategory = givenByCategory,
    )
  )

  val state: StateFlow<State> = _state.asStateFlow()

  /** Guards every write to [_state] and [generation]. */
  private val lock = Any()

  private var generation = 0L

  /** Optimistic spends not yet settled. Guarded by [lock]. */
  private var unsettledSpends = 0

  /** One spend on the wire at a time, so responses settle in send order. */
  private val spendLock = Mutex()

  // MARK: - Today

  /** Hearts credited so far today. Derived from the tally's day, so a ledger
   * left open past midnight reads zero on its own — no timer. */
  val heartsEarnedToday: Int get() = _state.value.heartsEarnedOn(today())

  /** Hearts today can still hand over. */
  val heartsRemainingToday: Int get() = _state.value.heartsRemainingOn(today())

  /** Whether today has given everything it has. */
  val isTodayFull: Boolean get() = heartsRemainingToday == 0

  val canGive: Boolean get() = _state.value.canGive

  /** Hearts this member has sent to one cause. */
  fun heartsGiven(categoryId: String): Int = _state.value.heartsGiven(categoryId)

  // MARK: - Earning

  /**
   * Credits hearts earned through practice — a completed DEEP Session calls
   * this. Only what's left of today's ceiling is credited, so the figure shown
   * is the whole truth; once the day is full this is a no-op.
   *
   * @return the hearts actually credited, so a caller can tell the member what
   *   happened rather than promising a heart the day can't give.
   */
  fun earn(hearts: Int = 1): Int = synchronized(lock) {
    val today = today()
    val current = rolledOver(_state.value, today)
    val credited = minOf(hearts, current.heartsRemainingOn(today))
    if (credited <= 0) {
      _state.value = current
      return@synchronized 0
    }
    _state.value = current.copy(balance = current.balance + credited, earnedTally = current.earnedTally + credited)
    credited
  }

  /**
   * Adopts the server's absolute wallet figures — the garden fetch feeds this
   * through `GardenStore.heartsChanged`. The per-cause spread is server truth
   * unless the server sent none while local sends exist.
   */
  fun hydrate(wallet: WalletSummary) {
    synchronized(lock) {
      val current = _state.value
      _state.value = current.copy(
        balance = wallet.heartsBalance,
        heartsGiven = wallet.heartsGiven,
        earnedTally = minOf(wallet.earnedToday, dailyEarnCeiling),
        tallyDay = today(),
        givenByCategory = if (wallet.givenByCategory.isNotEmpty() || current.givenByCategory.isEmpty()) {
          wallet.givenByCategory
        } else {
          current.givenByCategory
        },
      )
    }
  }

  /**
   * Applies a settled award. Absolutes SET the balance and today's tally, so
   * the completion beat's optimistic [earn] is reconciled rather than
   * double-counted; the delta path only serves responses without snapshots.
   */
  fun apply(grant: AwardGrant) {
    synchronized(lock) {
      val today = today()
      var next = _state.value
      val balanceNow = grant.heartsBalance
      if (balanceNow != null) {
        next = next.copy(balance = balanceNow)
      } else if (grant.hearts > 0) {
        next = next.copy(balance = next.balance + grant.hearts)
      }
      val earnedToday = grant.heartsEarnedToday
      if (earnedToday != null) {
        next = next.copy(earnedTally = minOf(earnedToday, dailyEarnCeiling), tallyDay = today)
      } else if (grant.hearts > 0) {
        next = rolledOver(next, today)
        next = next.copy(earnedTally = minOf(next.earnedTally + grant.hearts, dailyEarnCeiling))
      }
      grant.heartsGiven?.let { next = next.copy(heartsGiven = it) }
      _state.value = next
    }
  }

  // MARK: - Giving

  /**
   * Sends [hearts] to the cause [categoryId] — and, when given, the specific
   * project the member tapped. The amount is clamped to the balance, so an
   * over-ask gives everything that's left rather than failing.
   *
   * Optimistic: the books move immediately, then the spend goes to the server
   * under a fresh idempotency UUID. Success reconciles to the server's
   * absolutes; any failure rolls the whole mutation back and leaves a quiet
   * [State.spendFailure]. The round trip finishes even if the caller is
   * cancelled, so an optimistic spend is always either confirmed or rolled
   * back. Without a remote (fixtures, previews) the send stays purely local.
   *
   * Spends are serialised: a second send's books move at once, but its
   * request waits for the first to settle, and the first's absolutes are not
   * adopted while the second is still pending (they would erase it).
   */
  suspend fun send(hearts: Int, categoryId: String, projectId: String? = null) {
    val spend = synchronized(lock) {
      val current = _state.value
      val amount = minOf(hearts, current.balance)
      if (amount <= 0) return
      _state.value = current.copy(
        balance = current.balance - amount,
        heartsGiven = current.heartsGiven + amount,
        givenByCategory = current.givenByCategory.adding(categoryId, amount),
        spendFailure = null,
      )
      if (remote != null) unsettledSpends++
      PendingSpend(generation, amount)
    }
    val remote = remote ?: return

    withContext(NonCancellable) {
      spendLock.withLock {
        if (synchronized(lock) { generation != spend.generation }) return@withLock
        val settled = try {
          remote.spend(UUID.randomUUID(), spend.amount, categoryId, projectId)
        } catch (_: Exception) {
          null
        }
        settle(spend, settled, categoryId)
      }
    }
  }

  /** Applies one spend's outcome, unless the ledger was reset since. */
  private fun settle(spend: PendingSpend, settled: WalletSummary?, categoryId: String) {
    synchronized(lock) {
      if (generation != spend.generation) return
      unsettledSpends--
      val current = _state.value
      if (settled != null) {
        // Another optimistic spend is still waiting: this snapshot predates
        // it, so keep the books as they are — the last spend reconciles.
        if (unsettledSpends > 0) return
        _state.value = current.copy(
          balance = settled.heartsBalance,
          heartsGiven = settled.heartsGiven,
          givenByCategory = settled.givenByCategory.ifEmpty { current.givenByCategory },
        )
      } else {
        _state.value = current.copy(
          balance = current.balance + spend.amount,
          heartsGiven = current.heartsGiven - spend.amount,
          givenByCategory = current.givenByCategory.adding(categoryId, -spend.amount),
          spendFailure = SpendFailure(amount = spend.amount, categoryId = categoryId),
        )
      }
    }
  }

  /** Clears the rollback caption once it has been seen. */
  fun clearSpendFailure() {
    synchronized(lock) { _state.value = _state.value.copy(spendFailure = null) }
  }

  /**
   * Forgets the signed-out account's wallet, so the next account never sees a
   * previous member's balance while its first garden fetch is still in
   * flight. Any spend still in flight is dropped when it settles.
   */
  fun resetLocalState() {
    synchronized(lock) {
      generation++
      unsettledSpends = 0
      _state.value = State(
        balance = 0,
        heartsGiven = 0,
        earnedTally = 0,
        tallyDay = today(),
        givenByCategory = emptyMap(),
      )
    }
  }

  // MARK: - Internals

  private class PendingSpend(val generation: Long, val amount: Int)

  private fun today(): LocalDate = LocalDate.ofInstant(clock.instant(), zone)

  /** [state] with its tally zeroed if its day is not [today]. */
  private fun rolledOver(state: State, today: LocalDate): State =
    if (state.tallyDay == today) state else state.copy(tallyDay = today, earnedTally = 0)

  private fun Map<String, Int>.adding(categoryId: String, amount: Int): Map<String, Int> {
    val total = (this[categoryId] ?: 0) + amount
    return if (total > 0) this + (categoryId to total) else this - categoryId
  }

  companion object {
    /** The most hearts one day of practice can hand over — mirrors the
     * server's daily cap. */
    const val dailyEarnCeiling = RewardRules.dailyHeartsCap

    // Fixtures — previews and tests only. Local (no remote), so a send never
    // leaves the device.

    /** A warm portfolio: the per-cause spread sums to `heartsGiven`, the day
     * part-filled. Mirrors [WalletSummary.sample]. */
    fun sample(clock: Clock, zone: ZoneId) = HeartLedger(
      remote = null,
      clock = clock,
      zone = zone,
      balance = 2_450,
      heartsGiven = 318,
      heartsEarnedToday = 12,
      givenByCategory = mapOf("peace" to 104, "healthcare" to 96, "nature" to 71, "education" to 47),
    )

    /** A first-run portfolio: hearts to give, nothing given yet, the day
     * untouched. */
    fun fresh(clock: Clock, zone: ZoneId) =
      HeartLedger(remote = null, clock = clock, zone = zone, balance = 120)

    /** An emptied portfolio with a full day behind it — the one case where
     * practice can't earn more until tomorrow. */
    fun spent(clock: Clock, zone: ZoneId) = HeartLedger(
      remote = null,
      clock = clock,
      zone = zone,
      balance = 0,
      heartsGiven = 980,
      heartsEarnedToday = dailyEarnCeiling,
      givenByCategory = mapOf(
        "peace" to 240, "healthcare" to 228, "nature" to 194, "education" to 176, "community" to 142,
      ),
    )
  }
}
