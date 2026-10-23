package io.appbeyond.freelance.deep.feature.practice.store

import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenState
import io.appbeyond.freelance.deep.feature.practice.model.PracticeCompletion
import io.appbeyond.freelance.deep.feature.practice.model.PracticeMath
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.shared.persistence.BlobStoring
import io.appbeyond.freelance.deep.shared.persistence.StoreJson
import io.appbeyond.freelance.deep.shared.persistence.readOrNull
import io.appbeyond.freelance.deep.shared.persistence.writeQuietly
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import java.time.Clock
import java.time.ZoneId
import java.util.UUID

/**
 * The member's practice journal: every completed session, and the aggregates
 * the garden grows from. One shared instance, so a session finished anywhere —
 * Garden, DEEP Sound, Global Pause — lands in the same journal.
 *
 * Ported from Deep/Deep/Features/Practice/Store/PracticeDefaultsStore.swift.
 * Local-first: [record] appends immediately; [push] offers unsynced entries to
 * the backend, and a failure simply leaves them unsynced for the next push (no
 * retry timer). The whole journal persists as one JSON blob:
 *
 * ```
 * {"completions":[{"id":"…","title":"Balancing breath","durationSeconds":300,
 *   "completedAt":"2026-07-23T05:00:00Z","isSynced":false}],"dailyGoalMinutes":10}
 * ```
 *
 * Differences from iOS:
 *
 * - [record] does not start a push itself; the caller launches [push] (iOS
 *   fires a detached `Task`). Pushing before sign-out is the caller's
 *   `withTimeoutOrNull { push() }`, so [push] stays cancellable.
 * - DIVERGENCE: a push sends at most [MAX_PUSH_BATCH] sessions per request —
 *   deep-api rejects larger batches (`z.array(...).max(200)`), which on iOS
 *   would wedge a long offline backlog forever.
 * - [push] is single-flight: a second call waits for the first and then sends
 *   only what is still unsynced, so nothing is offered twice at once.
 * - Every async call is stamped with a generation; one that lands after
 *   [reset] neither re-adds entries nor forwards awards.
 */
class PracticeJournal(
  private val remote: PracticeRemote,
  private val blob: BlobStoring,
  private val clock: Clock,
  private val zone: ZoneId,
) {

  /** The journal — also, verbatim, the persisted blob. */
  @Serializable
  data class State(
    val completions: List<PracticeCompletion> = emptyList(),
    /** The gentle daily goal, in minutes. */
    val dailyGoalMinutes: Int = DEFAULT_DAILY_GOAL_MINUTES,
  )

  private val _state = MutableStateFlow(State())

  val state: StateFlow<State> = _state.asStateFlow()

  /**
   * Awards settled by a push land here — the app points this at the shared
   * ingest so the ledger and garden reconcile.
   */
  @Volatile
  var awardSink: (suspend (AwardGrant) -> Unit)? = null

  /** Guards every write to [_state], [generation] and [touched]. Never held
   * across a suspension. */
  private val lock = Any()

  private var generation = 0L

  private var touched = false

  private val restoreLock = Mutex()

  @Volatile
  private var restored = false

  private val pushLock = Mutex()

  private val persistLock = Mutex()

  // MARK: - Derived

  val completions: List<PracticeCompletion> get() = _state.value.completions

  val dailyGoalMinutes: Int get() = _state.value.dailyGoalMinutes

  fun minutesToday(): Int = PracticeMath.minutesToday(completions, zone, clock)

  fun completionsToday(): Int = PracticeMath.completionsToday(completions, zone, clock)

  fun currentStreakDays(): Int = PracticeMath.currentStreakDays(completions, zone, clock)

  fun longestStreakDays(): Int = PracticeMath.longestStreakDays(completions, zone)

  /** The garden's practice card, projected from the journal as it stands. */
  fun gardenState(): GardenState = GardenState(
    minutesToday = minutesToday(),
    dailyGoalMinutes = dailyGoalMinutes,
    streakDays = currentStreakDays(),
  )

  // MARK: - Journal

  /**
   * Adopts the persisted journal, once. Every suspending member calls this
   * first; calling it eagerly at launch just warms the aggregates.
   */
  suspend fun restore() {
    if (restored) return
    restoreLock.withLock {
      if (restored) return
      val stored = blob.readOrNull()?.let { json ->
        runCatching { StoreJson.decodeFromString(State.serializer(), json) }.getOrNull()
      }
      synchronized(lock) {
        if (stored != null && !touched) _state.value = stored
      }
      restored = true
    }
  }

  /**
   * Records a finished session locally — unsynced, stamped now — and returns
   * it. Launch [push] afterwards to offer it to the backend. Once appended,
   * the entry is written to disk even if the caller is cancelled, so a
   * finished session is never lost on relaunch.
   */
  suspend fun record(title: String, durationSeconds: Int): PracticeCompletion {
    restore()
    val completion = PracticeCompletion(
      id = UUID.randomUUID(),
      title = title,
      durationSeconds = durationSeconds,
      completedAt = clock.instant(),
      isSynced = false,
    )
    withContext(NonCancellable) {
      synchronized(lock) {
        touched = true
        _state.value = _state.value.let { it.copy(completions = it.completions + completion) }
      }
      persist()
    }
    return completion
  }

  /**
   * Offers every unsynced completion to the backend in batches of at most
   * [MAX_PUSH_BATCH], marking what each batch accepted and forwarding its
   * awards to [awardSink]. Stops quietly at the first failure — the rest wait
   * for the next push. Uploads are idempotent by id server-side.
   *
   * Only the network call is cancellable (so `withTimeoutOrNull { push() }`
   * works). Once a batch's response is in hand, marking it synced, writing
   * that to disk and delivering its awards run to completion together — a
   * batch is never marked synced with its awards dropped. A [reset] stops the
   * push before its next batch and before any further award.
   */
  suspend fun push() {
    restore()
    pushLock.withLock {
      val stamp = synchronized(lock) { generation }
      val pending = _state.value.completions.filter { !it.isSynced }
      for (batch in pending.chunked(MAX_PUSH_BATCH)) {
        if (synchronized(lock) { generation != stamp }) return
        val result = try {
          remote.push(batch)
        } catch (cancelled: CancellationException) {
          throw cancelled
        } catch (_: Exception) {
          return
        }

        val accepted = result.synced.toSet()
        val settled = withContext(NonCancellable) {
          val current = synchronized(lock) {
            if (generation != stamp) return@synchronized false
            _state.value = _state.value.let { state ->
              state.copy(
                completions = state.completions.map {
                  if (!it.isSynced && it.id in accepted) it.copy(isSynced = true) else it
                },
              )
            }
            true
          }
          if (!current) return@withContext false
          persist()

          // Awards ride the sync: hand the settled grant (absolutes included)
          // to whoever reconciles the ledger and garden — unless the journal
          // was reset while the batch was being written.
          val grant = result.grant
          if (grant != null && synchronized(lock) { generation == stamp }) awardSink?.invoke(grant)
          true
        }
        if (!settled) return
      }
    }
  }

  /**
   * Merges the server's log into the journal by id — entries recorded on
   * other installs arrive here, marked synced. Known ids are never updated or
   * removed. Errors are swallowed; the local journal is already whole.
   */
  suspend fun pull() {
    restore()
    val stamp = synchronized(lock) { generation }
    val fetched = try {
      remote.pull()
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (_: Exception) {
      return
    }

    val merged = synchronized(lock) {
      if (generation != stamp) return@synchronized false
      val state = _state.value
      val known = state.completions.mapTo(HashSet()) { it.id }
      val unseen = fetched
        .filter { it.id !in known }
        .distinctBy { it.id }
        .map { it.copy(isSynced = true) }
      if (unseen.isEmpty()) return@synchronized false
      touched = true
      _state.value = state.copy(completions = (state.completions + unseen).sortedBy { it.completedAt })
      true
    }
    if (merged) persist()
  }

  /** Pushes anything unsynced, then pulls and merges the server's log. */
  suspend fun refresh() {
    push()
    pull()
  }

  /**
   * Empties the journal and persists the empty state — log out and account
   * deletion call this. A push or pull still in flight for the old account is
   * dropped when it lands.
   */
  suspend fun reset() {
    restore()
    synchronized(lock) {
      generation++
      touched = true
      _state.value = State()
    }
    persist()
  }

  // MARK: - Internals

  /** Writes the state current at that moment; non-cancellable, so a
   * committed mutation always reaches disk. */
  private suspend fun persist() = withContext(NonCancellable) {
    persistLock.withLock {
      blob.writeQuietly(StoreJson.encodeToString(State.serializer(), _state.value))
    }
  }

  companion object {
    const val DEFAULT_DAILY_GOAL_MINUTES = 10

    /** deep-api's per-request ceiling on `POST /me/practice/sessions`. */
    const val MAX_PUSH_BATCH = 200
  }
}
