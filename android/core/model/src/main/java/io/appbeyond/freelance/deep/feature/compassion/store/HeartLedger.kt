package io.appbeyond.freelance.deep.feature.compassion.store

import io.appbeyond.freelance.deep.auth.HttpStatusCarrying
import io.appbeyond.freelance.deep.feature.compassion.model.CompassionCatalog
import io.appbeyond.freelance.deep.feature.compassion.model.CompassionPool
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.feature.rewards.model.RewardRules
import io.appbeyond.freelance.deep.feature.rewards.model.WalletSummary
import io.appbeyond.freelance.deep.feature.rewards.store.RewardsRemote
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
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
 * where, how much of today's earning ceiling is left — and the community's
 * pooled totals the Compassion tab draws beside them.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Models/HeartLedger.swift.
 * The day maths reads [clock] in [zone] rather than `Calendar.current`, so the
 * day boundary follows the member's timezone and a test can pin it. Persists
 * nothing (parity): the first garden/wallet fetch hydrates it.
 *
 * The community side ([State.pool]) is seeded from [CompassionCatalog] and
 * climbs only with this device's own sends, exactly as iOS's
 * `categories[i].heartsShared` does: the server reports no pooled totals.
 * A refused send takes its hearts back out of the pool; a reset leaves the
 * pool alone, because it is app content, not account state.
 *
 * **How a spend is booked.** The ledger keeps two things apart: the
 * *confirmed books* — the last absolutes the server sent, plus local credits —
 * and the *unsettled spends*, optimistic gifts whose POST has not answered.
 * What the member sees is the books less the unsettled spends. A spend that
 * succeeds adopts the server's absolutes as the new books; one that is refused
 * simply leaves the unsettled list, so its hearts reappear without any
 * arithmetic of their own.
 *
 * That split is the week-4 carry-over's fix. iOS (and Android until v0.0.5)
 * kept one set of figures: a wallet refresh landing mid-gift overwrote them
 * with server truth — which cannot include a gift the server then refuses —
 * and the rollback added the gift back on top, counting it twice until the
 * next refresh. Here a refresh replaces only the books, the unsettled gift is
 * still subtracted from what shows, and a refusal removes it once. The same
 * holds for an award's absolutes ([apply]) arriving mid-gift.
 *
 * The one cost: a refresh that the server answered *after* committing the gift
 * already counts it, so until the gift's own response lands (moments later)
 * the balance reads that gift short. A brief undercount, corrected by the
 * gift's own answer, instead of a lasting overcount — and if that answer is
 * lost in transit, the re-send under the same id ([reconcile]) brings it back.
 *
 * **A refusal is only ever the server's.** Each spend carries one idempotency
 * UUID for its whole life, and deep-api records a spend under that id at most
 * once. So only a 4xx answer — the server read the request and said no — rolls
 * a gift back and raises [State.spendFailure] ("they're back in your
 * balance"). A timeout, a dropped connection, a 5xx or an unreadable body is
 * an *unknown outcome*: the server may well have committed it (QA round 1, B3:
 * a stalled request committed after the client gave up). Such a spend is
 * retried under the same id ([retryDelaysMillis]); if it still can't be
 * confirmed it stays unsettled — its hearts still out of the balance and in
 * the pool — and [reconcile] re-sends it later, when the server answers
 * either way: a duplicate returns the committed wallet, a first arrival
 * commits it, and a 409 is a genuine refusal.
 *
 * Every spend is stamped with a generation; one that settles after
 * [resetLocalState] is dropped, so a previous account's wallet never lands on
 * the next one. Spends go to the server one at a time, so each response's
 * snapshot covers every earlier spend and none of the later ones still queued.
 *
 * Known, at iOS parity (not fixed here): a wallet or grant whose `earnedToday`
 * was computed for yesterday but lands just after midnight is labelled with
 * today's date (the tally day is taken from the device clock on arrival),
 * exactly as iOS does.
 */
class HeartLedger(
  private val remote: RewardsRemote?,
  private val clock: Clock,
  private val zone: ZoneId,
  balance: Int = 0,
  heartsGiven: Int = 0,
  heartsEarnedToday: Int = 0,
  givenByCategory: Map<String, Int> = emptyMap(),
  pool: CompassionPool = CompassionCatalog.launchPool,
  /** The pauses before each re-send of a spend whose outcome is unknown; one
   * attempt plus one per entry. */
  private val retryDelaysMillis: List<Long> = listOf(1_000L, 3_000L),
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
    /** The community's pooled hearts, per cause and per project. */
    val pool: CompassionPool = CompassionPool.empty,
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

    /** Whether [today] has given everything it has. */
    fun isFullOn(today: LocalDate): Boolean = heartsRemainingOn(today) == 0

    /** Hearts this member has sent to one cause. */
    fun heartsGiven(categoryId: String): Int = givenByCategory[categoryId] ?: 0

    /** Distinct causes this member has contributed to. */
    val causesSupported: Int get() = givenByCategory.count { it.value > 0 }
  }

  /** The confirmed figures: the server's last absolutes, plus local credits. */
  private data class Books(
    val balance: Int,
    val heartsGiven: Int,
    val givenByCategory: Map<String, Int>,
  )

  /** One optimistic spend whose POST has not answered yet — or answered
   * nothing the ledger can trust. [id] is its idempotency key for life. */
  private class PendingSpend(
    val generation: Long,
    val id: UUID,
    val amount: Int,
    val categoryId: String,
    val projectId: String?,
  ) {
    /** Every attempt so far ended without an answer; [reconcile] re-sends it.
     * Guarded by [lock]. */
    var unconfirmed = false
  }

  /** What one attempt at a spend learned. */
  private sealed interface Outcome {
    /** The server holds the spend; its wallet afterwards. */
    data class Accepted(val wallet: WalletSummary) : Outcome

    /** The server read the request and said no. */
    data object Refused : Outcome
  }

  private var books = Books(balance, heartsGiven, givenByCategory)

  /** Guarded by [lock]; in send order. */
  private val unsettled = mutableListOf<PendingSpend>()

  private val _state = MutableStateFlow(
    State(
      balance = balance,
      heartsGiven = heartsGiven,
      earnedTally = minOf(heartsEarnedToday, dailyEarnCeiling),
      tallyDay = today(),
      givenByCategory = givenByCategory,
      pool = pool,
    )
  )

  val state: StateFlow<State> = _state.asStateFlow()

  /** Guards every write to [_state], [books], [unsettled] and [generation]. */
  private val lock = Any()

  private var generation = 0L

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

  /** The local day the ledger reads "today" as — for screens that derive
   * [State.heartsEarnedOn] from a collected state. */
  fun today(): LocalDate = clock.instant().atZone(zone).toLocalDate()

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
    books = books.copy(balance = books.balance + credited)
    _state.value = current.copy(earnedTally = current.earnedTally + credited).withBooks()
    credited
  }

  /**
   * Adopts the server's absolute wallet figures — the garden fetch feeds this
   * through `GardenStore.heartsChanged`. The per-cause spread is server truth
   * unless the server sent none while local sends exist. Gifts still in
   * flight stay subtracted from what shows (see the class note).
   */
  fun hydrate(wallet: WalletSummary) {
    synchronized(lock) {
      books = Books(
        balance = wallet.heartsBalance,
        heartsGiven = wallet.heartsGiven,
        givenByCategory = if (wallet.givenByCategory.isNotEmpty() || books.givenByCategory.isEmpty()) {
          wallet.givenByCategory
        } else {
          books.givenByCategory
        },
      )
      _state.value = _state.value.copy(
        earnedTally = minOf(wallet.earnedToday, dailyEarnCeiling),
        tallyDay = today(),
      ).withBooks()
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
        books = books.copy(balance = balanceNow)
      } else if (grant.hearts > 0) {
        books = books.copy(balance = books.balance + grant.hearts)
      }
      val earnedToday = grant.heartsEarnedToday
      if (earnedToday != null) {
        next = next.copy(earnedTally = minOf(earnedToday, dailyEarnCeiling), tallyDay = today)
      } else if (grant.hearts > 0) {
        next = rolledOver(next, today)
        next = next.copy(earnedTally = minOf(next.earnedTally + grant.hearts, dailyEarnCeiling))
      }
      grant.heartsGiven?.let { books = books.copy(heartsGiven = it) }
      _state.value = next.withBooks()
    }
  }

  // MARK: - Giving

  /**
   * Sends [hearts] to the cause [categoryId] — and, when given, the specific
   * project the member tapped. The amount is clamped to the balance, so an
   * over-ask gives everything that's left rather than failing.
   *
   * Optimistic: the books and the pool move immediately, then the spend goes
   * to the server under a fresh idempotency UUID. Success reconciles to the
   * server's absolutes; a refusal (4xx) rolls the whole mutation back and
   * leaves a quiet [State.spendFailure]. An unknown outcome is re-sent under
   * the same UUID and, failing that, left unsettled for [reconcile] — never
   * reported as refused (see the class note). The round trip finishes even
   * if the caller is cancelled. Without a remote (fixtures, previews) the
   * send stays purely local.
   *
   * Spends are serialised: a second send's figures move at once, but its
   * request waits for the first to settle — and for any earlier spend still
   * unconfirmed to be re-sent first.
   */
  suspend fun send(hearts: Int, categoryId: String, projectId: String? = null) {
    val spend = synchronized(lock) {
      val current = _state.value
      val amount = minOf(hearts, current.balance)
      if (amount <= 0) return
      val pending = PendingSpend(generation, UUID.randomUUID(), amount, categoryId, projectId)
      if (remote != null) {
        unsettled += pending
      } else {
        books = books.giving(amount, categoryId)
      }
      _state.value = current.copy(
        pool = current.pool.adding(categoryId, projectId, amount),
        spendFailure = null,
      ).withBooks()
      pending
    }
    val remote = remote ?: return

    withContext(NonCancellable) {
      spendLock.withLock {
        resendUnconfirmed(remote)
        deliver(remote, spend, retryDelaysMillis)
      }
    }
  }

  /**
   * Re-sends, oldest first, every spend whose outcome is still unknown, under
   * its original idempotency UUID — so a gift the server already committed
   * comes back as that commit, and one it never saw is committed now. Called
   * after a wallet refresh (the network is evidently back) and before each
   * new send. Stops at the first spend that still gets no answer, keeping
   * the rest in order for the next call. A no-op when nothing is unconfirmed.
   */
  suspend fun reconcile() {
    val remote = remote ?: return
    if (!hasUnconfirmedSpends) return
    withContext(NonCancellable) {
      spendLock.withLock { resendUnconfirmed(remote) }
    }
  }

  /** Whether a spend is waiting on [reconcile] — its outcome unknown. */
  val hasUnconfirmedSpends: Boolean get() = synchronized(lock) { unsettled.any { it.unconfirmed } }

  /** Call with [spendLock] held. */
  private suspend fun resendUnconfirmed(remote: RewardsRemote) {
    val waiting = synchronized(lock) { unsettled.filter { it.unconfirmed } }
    for (spend in waiting) {
      if (!deliver(remote, spend, retryDelaysMillis = emptyList())) return
    }
  }

  /**
   * Sends [spend] until the server answers, pausing [retryDelaysMillis]
   * between attempts. Settles it on an answer and returns true; with no
   * answer after the last attempt it marks the spend unconfirmed and returns
   * false. Call with [spendLock] held.
   */
  private suspend fun deliver(remote: RewardsRemote, spend: PendingSpend, retryDelaysMillis: List<Long>): Boolean {
    var attempt = 0
    while (true) {
      if (synchronized(lock) { generation != spend.generation }) return true
      val outcome = try {
        Outcome.Accepted(remote.spend(spend.id, spend.amount, spend.categoryId, spend.projectId))
      } catch (error: Exception) {
        if (isRefusal(error)) Outcome.Refused else null
      }
      if (outcome != null) {
        settle(spend, outcome)
        return true
      }
      if (attempt >= retryDelaysMillis.size) {
        synchronized(lock) { spend.unconfirmed = true }
        return false
      }
      delay(retryDelaysMillis[attempt++])
    }
  }

  /** Send a single heart — the one-tap paths. No-op once the balance is spent. */
  suspend fun sendHeart(categoryId: String, projectId: String? = null) = send(1, categoryId, projectId)

  /** Applies one spend's outcome, unless the ledger was reset since. */
  private fun settle(spend: PendingSpend, outcome: Outcome) {
    synchronized(lock) {
      if (generation != spend.generation) return
      unsettled.remove(spend)
      val current = _state.value
      if (outcome is Outcome.Accepted) {
        val settled = outcome.wallet
        // Covers this spend and every earlier one; the later ones are still
        // queued behind it, so they stay subtracted on top.
        books = Books(
          balance = settled.heartsBalance,
          heartsGiven = settled.heartsGiven,
          givenByCategory = settled.givenByCategory.ifEmpty { books.givenByCategory },
        )
        _state.value = current.withBooks()
      } else {
        // Refused. The books never held this spend; dropping it from the
        // unsettled list is the whole rollback. Only the pool moved on its own.
        _state.value = current.copy(
          pool = current.pool.adding(spend.categoryId, spend.projectId, -spend.amount),
          spendFailure = SpendFailure(amount = spend.amount, categoryId = spend.categoryId),
        ).withBooks()
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
   * flight. Any spend still in flight is dropped when it settles. The pool
   * stays: it is the community's, not the account's.
   */
  fun resetLocalState() {
    synchronized(lock) {
      generation++
      unsettled.clear()
      books = Books(balance = 0, heartsGiven = 0, givenByCategory = emptyMap())
      _state.value = State(
        balance = 0,
        heartsGiven = 0,
        earnedTally = 0,
        tallyDay = today(),
        givenByCategory = emptyMap(),
        pool = _state.value.pool,
      )
    }
  }

  // MARK: - Internals

  /** [this] state with the member's figures recomputed: the books, less every
   * unsettled spend. Call with [lock] held. */
  private fun State.withBooks(): State {
    var shown = books
    for (spend in unsettled) shown = shown.giving(spend.amount, spend.categoryId)
    return copy(
      // A refresh that already counted an in-flight gift could take this below
      // zero for a moment; nothing shows a negative balance.
      balance = maxOf(0, shown.balance),
      heartsGiven = shown.heartsGiven,
      givenByCategory = shown.givenByCategory,
    )
  }

  private fun Books.giving(amount: Int, categoryId: String): Books = copy(
    balance = balance - amount,
    heartsGiven = heartsGiven + amount,
    givenByCategory = givenByCategory.adding(categoryId, amount),
  )

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

    /**
     * Whether [error] is the server declining the spend: a 4xx it answered
     * (409 `insufficient_hearts`, a validation 400, a 401 once the session is
     * gone). 408 and 429 say the request was not processed *yet*, so they are
     * retried like a timeout. Everything else is an unknown outcome.
     */
    internal fun isRefusal(error: Throwable): Boolean =
      error is HttpStatusCarrying && error.status in 400..499 && error.status != 408 && error.status != 429

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

    /** A small balance below the quick-amount ladder — iOS's
     * `HeartLedger(balance: 7, heartsGiven: 41)` preview. */
    fun small(clock: Clock, zone: ZoneId) =
      HeartLedger(remote = null, clock = clock, zone = zone, balance = 7, heartsGiven = 41)

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

    /** Spent, but with the day still open — the caption points at the next
     * practice instead of tomorrow. */
    fun spentDayOpen(clock: Clock, zone: ZoneId) =
      HeartLedger(remote = null, clock = clock, zone = zone, balance = 0, heartsGiven = 40)

    /** A portfolio whose last send the server refused and rolled back — the
     * quiet caption under the send/donate CTAs. */
    fun sendRefused(clock: Clock, zone: ZoneId) = sample(clock, zone).apply {
      _state.value = _state.value.copy(spendFailure = SpendFailure(amount = 1, categoryId = "nature"))
    }
  }
}
