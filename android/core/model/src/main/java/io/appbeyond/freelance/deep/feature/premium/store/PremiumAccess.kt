package io.appbeyond.freelance.deep.feature.premium.store

import io.appbeyond.freelance.deep.feature.premium.model.ServerEntitlement
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionState
import io.appbeyond.freelance.deep.shared.persistence.BlobStoring
import io.appbeyond.freelance.deep.shared.persistence.StoreJson
import io.appbeyond.freelance.deep.shared.persistence.readOrNull
import io.appbeyond.freelance.deep.shared.persistence.writeQuietly
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable

/**
 * The app's one answer to "does this person have DEEP Premium?".
 *
 * Every lock decision reads [hasPremium] and hands it to
 * [io.appbeyond.freelance.deep.feature.premium.model.PremiumGate] — no screen
 * asks the purchasing store directly. Conformers: [ReconciledPremiumAccess],
 * the live one, and [FakePremiumAccess] for previews and tests.
 */
interface PremiumAccess {

  /** The answer every lock reads. */
  val hasPremium: StateFlow<Boolean>

  /**
   * Moves whenever content fetched earlier may carry stale verdicts: on every
   * flip of [hasPremium], *and* whenever the server changes (or first gives)
   * its own answer. The second matters right after a purchase — [hasPremium]
   * turned true on the store's word and stays true when the server catches
   * up, but the audio the server withheld until then only arrives with a
   * re-fetch. Content screens key their loading on it.
   */
  val contentEpoch: StateFlow<Int>

  /** The server's full answer, when one arrived this session — Settings' manage link reads its store. */
  val entitlement: StateFlow<ServerEntitlement?>

  /**
   * A purchase — or a restore that found one — just completed: unlock now,
   * on the store's word, and have the server confirm it behind the scenes.
   */
  fun didPurchase()
}

/**
 * Asks the server whether this member has DEEP Premium. A seam of its own so
 * the account store never learns premium exists, and so
 * [ReconciledPremiumAccess] tests without a network. Ported from
 * `EntitlementFetching` in Deep/Deep/Features/Premium/Store/EntitlementFetching.swift.
 *
 * Both calls answer null when there is no answer to give — signed out, or an
 * older server that doesn't send the entitlement — and throw when the server
 * couldn't be reached.
 */
interface EntitlementFetching {

  /** The current answer, from `GET /me`. */
  suspend fun currentEntitlement(): ServerEntitlement?

  /**
   * Asks the server to re-check with RevenueCat now rather than wait for the
   * webhook (`POST /me/entitlement/refresh`, rate-limited per member).
   */
  suspend fun refreshEntitlement(): ServerEntitlement?
}

/**
 * [PremiumAccess] as the union of the server, the store and a short
 * post-purchase grace window. Ported from
 * Deep/Deep/Features/Premium/Store/PremiumAccess.swift.
 *
 * **The rule is the union.** Premium is granted when the server says so,
 * *or* the store says so, *or* a purchase has just completed and the server
 * hasn't caught up yet. The costs are asymmetric: a false lock on a member
 * whose webhook hasn't landed is a refund request, while a false unlock
 * costs at most a tap — the server still withholds the audio itself.
 *
 * The server's last answer is remembered per member (one JSON blob,
 * `{"owner":…,"active":…}`), so a launch where the store is still checking —
 * or the server is unreachable — opens on what the server last said rather
 * than regressing to locked. A different member, or none, never inherits it.
 *
 * Differences from iOS, all forced by threads rather than chosen:
 * - The blob is read on first use ([restore]) rather than in the
 *   constructor; every suspending member restores first.
 * - State is guarded by one lock and published through [StateFlow]s; an
 *   answer fetched under one identity generation is dropped under the lock
 *   if the member changed meanwhile (iOS relies on `@MainActor` ordering).
 *
 * @param storeStatus the purchasing store's answer, observed for the life of
 *   [scope] so a renewal, refund or expiry reaches [hasPremium] unasked.
 * @param fetcher the server; null leaves the server's answer to whatever
 *   [adopt] is handed (previews).
 * @param blob where the server's last answer is remembered.
 * @param scope process-lifetime: the store observation, the grace timer and
 *   the confirmation ladder run here, so no screen closing cancels them.
 * @param now wall-clock milliseconds, for the grace window.
 * @param confirmationDelaysMillis the ladder's waits after a purchase.
 */
class ReconciledPremiumAccess(
  private val storeStatus: StateFlow<SubscriptionState>,
  private val fetcher: EntitlementFetching?,
  private val blob: BlobStoring,
  private val scope: CoroutineScope,
  private val now: () -> Long = System::currentTimeMillis,
  private val confirmationDelaysMillis: List<Long> = CONFIRMATION_DELAYS_MILLIS,
) : PremiumAccess {

  private val _hasPremium = MutableStateFlow(resolve(server = null, store = storeStatus.value, insideGrace = false))
  override val hasPremium: StateFlow<Boolean> = _hasPremium.asStateFlow()

  private val _contentEpoch = MutableStateFlow(0)
  override val contentEpoch: StateFlow<Int> = _contentEpoch.asStateFlow()

  private val _entitlement = MutableStateFlow<ServerEntitlement?>(null)
  override val entitlement: StateFlow<ServerEntitlement?> = _entitlement.asStateFlow()

  private val _server = MutableStateFlow<Boolean?>(null)

  /**
   * What the server last said for this member: null until it has ever
   * answered (or after sign-out), remembered across launches otherwise.
   */
  val server: StateFlow<Boolean?> = _server.asStateFlow()

  /** Moves exactly once each time [hasPremium] flips. */
  @Volatile
  var flipCount: Int = 0
    private set

  /** Guards every field below and every write to the flows. Never held across a suspension. */
  private val lock = Any()

  /** The remembered answer and its owner, as last read or written. */
  private var remembered: ServerAnswer? = null

  /** Whether the server has answered since launch — a remembered answer is a stand-in, not an answer. */
  private var answeredThisSession = false

  /** Until when (wall-clock millis) a completed purchase unlocks on its own word. */
  private var graceUntil: Long? = null

  /**
   * Moves whenever the member changes. An answer fetched for one member that
   * lands after another (or none) is signed in is dropped, never adopted.
   */
  private var identityGeneration = 0

  private var graceJob: Job? = null
  private var confirmationJob: Job? = null

  private val restoreLock = Mutex()

  @Volatile
  private var restored = false

  /** Serialises blob writes; each writes the answer current at that moment. */
  private val persistLock = Mutex()

  init {
    scope.launch {
      storeStatus.collect { reconcile() }
    }
  }

  // MARK: - Persistence

  /**
   * Adopts the remembered answer, once. Every suspending member calls this
   * first; calling it eagerly at launch carries a member's lock state from
   * the first frame.
   */
  suspend fun restore() {
    if (restored) return
    restoreLock.withLock {
      if (restored) return
      val stored = blob.readOrNull()?.let { json ->
        runCatching { StoreJson.decodeFromString(ServerAnswer.serializer(), json) }.getOrNull()
      }
      synchronized(lock) {
        if (stored != null && remembered == null) {
          remembered = stored
          _server.value = stored.active
          reconcileLocked()
        }
      }
      restored = true
    }
  }

  // MARK: - The server's answer

  /**
   * Asks the server. Any failure changes nothing: the last answer — the
   * server's remembered one, or the store's — stands.
   */
  suspend fun refresh() {
    restore()
    val fetcher = fetcher ?: return
    val generation = synchronized(lock) { identityGeneration }
    val answer = try {
      fetcher.currentEntitlement()
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (_: Exception) {
      return
    }
    adopt(answer, generation)
  }

  /** Asks the server only if it hasn't answered since launch — the session restore's `/me` usually has. */
  suspend fun refreshIfUnanswered() {
    restore()
    if (synchronized(lock) { answeredThisSession }) return
    refresh()
  }

  /**
   * Takes an answer the server sent, from wherever it arrived (`/me`, or the
   * sign-in response). Null is an older server saying nothing, which changes
   * nothing.
   */
  suspend fun adopt(answer: ServerEntitlement?) = adopt(answer, generation = null)

  private suspend fun adopt(answer: ServerEntitlement?, generation: Int?) {
    if (answer == null) return
    restore()
    val adopted = synchronized(lock) {
      if (generation != null && generation != identityGeneration) return@synchronized false
      val previous = _server.value
      answeredThisSession = true
      _entitlement.value = answer
      _server.value = answer.isActive
      remembered = ServerAnswer(owner = remembered?.owner, active = answer.isActive)
      val flipped = reconcileLocked()
      // The server changed its mind — or answered for the first time —
      // without hasPremium moving (a store or a grace window already carried
      // it): content still needs the audio the server now releases, or no
      // longer does.
      if (!flipped && previous != answer.isActive) _contentEpoch.value += 1
      true
    }
    if (adopted) persist()
  }

  /**
   * Follows the signed-in member. A different member — or none — must never
   * inherit the previous one's remembered answer, and an answer with no owner
   * at all can only be one that landed after a sign-out.
   */
  suspend fun identify(userId: String?) {
    restore()
    synchronized(lock) {
      if (userId == null) {
        forgetServerLocked()
      } else {
        val current = remembered
        if (current != null && current.owner != userId && (current.owner != null || current.active != null)) {
          forgetServerLocked()
        }
        remembered = ServerAnswer(owner = userId, active = _server.value)
      }
    }
    persist()
  }

  private fun forgetServerLocked() {
    identityGeneration += 1
    confirmationJob?.cancel()
    confirmationJob = null
    remembered = null
    _server.value = null
    _entitlement.value = null
    graceUntil = null
    answeredThisSession = false
    reconcileLocked()
  }

  // MARK: - After a purchase

  /**
   * Unlocks now, on the store's word, for [GRACE_WINDOW_MILLIS], and keeps
   * asking the server until it agrees or the ladder runs out. The server is
   * first nudged to re-check with RevenueCat rather than wait for the
   * webhook; that nudge failing (rate-limited, or not configured locally) is
   * fine — the ladder still asks. A newer purchase replaces the ladder.
   */
  override fun didPurchase() {
    synchronized(lock) {
      graceUntil = now() + GRACE_WINDOW_MILLIS
      reconcileLocked()
      graceJob?.cancel()
      graceJob = scope.launch {
        delay(GRACE_WINDOW_MILLIS)
        reconcile()
      }
      confirmationJob?.cancel()
      confirmationJob = scope.launch { confirmPurchase() }
    }
  }

  /** The confirmation ladder, callable directly so tests can run it to the end. */
  suspend fun confirmPurchase() {
    restore()
    val fetcher = fetcher ?: return
    val generation = synchronized(lock) { identityGeneration }
    adopt(answerOrNull { fetcher.refreshEntitlement() }, generation)
    for (wait in confirmationDelaysMillis) {
      if (synchronized(lock) { _server.value == true || generation != identityGeneration }) return
      delay(wait)
      adopt(answerOrNull { fetcher.currentEntitlement() }, generation)
    }
  }

  private suspend fun answerOrNull(ask: suspend () -> ServerEntitlement?): ServerEntitlement? =
    try {
      ask()
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (_: Exception) {
      null
    }

  // MARK: - Reconciling

  /** Recomputes the answer, counting a flip only when it actually flips. Returns whether it did. */
  fun reconcile(): Boolean = synchronized(lock) { reconcileLocked() }

  private fun reconcileLocked(): Boolean {
    val insideGrace = graceUntil?.let { now() < it } ?: false
    val next = resolve(server = _server.value, store = storeStatus.value, insideGrace = insideGrace)
    if (next == _hasPremium.value) return false
    _hasPremium.value = next
    flipCount += 1
    _contentEpoch.value += 1
    return true
  }

  /** Writes the remembered answer as it stands now. Non-cancellable, like every committed mutation. */
  private suspend fun persist() = withContext(NonCancellable) {
    persistLock.withLock {
      val current = synchronized(lock) { remembered }
      blob.writeQuietly(current?.let { StoreJson.encodeToString(ServerAnswer.serializer(), it) })
    }
  }

  /** The server's last answer and the DEEP user id it belongs to. Its own type, so the blob's shape never drifts with [ServerEntitlement]. */
  @Serializable
  private data class ServerAnswer(
    /** The DEEP user id the answer belongs to, once known. */
    val owner: String? = null,
    /** The server's answer; null while the owner is known but unanswered. */
    val active: Boolean? = null,
  )

  companion object {
    /** How long a completed purchase unlocks on its own word, while the server hears about it. */
    const val GRACE_WINDOW_MILLIS = 120_000L

    /** The waits between asking the server again after a purchase — stretched to span the grace window. */
    val CONFIRMATION_DELAYS_MILLIS: List<Long> = listOf(1_000L, 2_000L, 4_000L, 8_000L, 15_000L, 30_000L, 60_000L)

    /**
     * The reconciliation truth table. The store being [SubscriptionState.Unknown]
     * — RevenueCat still checking — counts for nothing on its own; the
     * server's remembered answer carries the launch until the store settles.
     */
    fun resolve(server: Boolean?, store: SubscriptionState, insideGrace: Boolean): Boolean =
      server == true || insideGrace || store is SubscriptionState.Subscribed
  }
}

/**
 * [PremiumAccess] held in memory, for previews and tests: the answer is
 * whatever it was given, and [didPurchase] only counts.
 */
class FakePremiumAccess(hasPremium: Boolean = false) : PremiumAccess {

  private val _hasPremium = MutableStateFlow(hasPremium)
  override val hasPremium: StateFlow<Boolean> = _hasPremium.asStateFlow()

  private val _contentEpoch = MutableStateFlow(0)
  override val contentEpoch: StateFlow<Int> = _contentEpoch.asStateFlow()

  private val _entitlement = MutableStateFlow(if (hasPremium) ServerEntitlement.member else null)
  override val entitlement: StateFlow<ServerEntitlement?> = _entitlement.asStateFlow()

  /** How many times [didPurchase] was called. */
  var purchases: Int = 0
    private set

  override fun didPurchase() {
    purchases += 1
    set(true)
  }

  /** Flips the answer, moving [contentEpoch] the way a real flip does. */
  fun set(hasPremium: Boolean) {
    if (_hasPremium.value == hasPremium) return
    _hasPremium.value = hasPremium
    _contentEpoch.value += 1
  }
}
