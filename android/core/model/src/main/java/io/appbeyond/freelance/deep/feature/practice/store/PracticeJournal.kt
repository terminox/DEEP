package io.appbeyond.freelance.deep.feature.practice.store

import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenState
import io.appbeyond.freelance.deep.feature.practice.model.ContinuityTransition
import io.appbeyond.freelance.deep.feature.practice.model.PracticeCompletion
import io.appbeyond.freelance.deep.feature.practice.model.PracticeMath
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.shared.persistence.BlobStoring
import io.appbeyond.freelance.deep.shared.persistence.InstantAsStringSerializer
import io.appbeyond.freelance.deep.shared.persistence.StoreJson
import io.appbeyond.freelance.deep.shared.persistence.readOrNull
import io.appbeyond.freelance.deep.shared.persistence.writeQuietly
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.Serializable
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
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
 *   "completedAt":"2026-07-23T05:00:00Z","isSynced":false}],"dailyGoalMinutes":10,
 *  "pauseDays":["2026-07-22"],"trackDays":["2026-07-23"],
 *  "remoteActivityDays":["2026-07-21"],"lastPulledAt":"2026-07-23T05:00:01Z"}
 * ```
 *
 * The rhythm counts any practice day: sessions, the pause and track day
 * markers, and the server's activity days. Every day is an ISO key, never a
 * localized calendar's.
 *
 * Differences from iOS:
 *
 * - [record] does not start a push itself; the caller launches [push] (iOS
 *   fires a detached `Task`). [flushPending] bounds [push] with
 *   `withTimeoutOrNull`, so [push] stays cancellable.
 * - iOS keeps one list of typed activity markers; here pause nights and
 *   finished sounds each keep their own list of day keys.
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
    /**
     * Local days ("YYYY-MM-DD", always ISO — never a localized calendar) an
     * attended Global Pause kept in the rhythm. A pause night is not a
     * session, so it adds no minutes and no completion; it only keeps the day.
     */
    val pauseDays: List<String> = emptyList(),
    /**
     * Local days a sound listened to its end kept in the rhythm — iOS's
     * `.track` activity markers. Like a pause night, no minutes and no
     * completion; and unlike one, it doesn't rest the reminder.
     */
    val trackDays: List<String> = emptyList(),
    /**
     * The server's activity days as last pulled ("YYYY-MM-DD") — days kept on
     * other installs, or before this one was signed in. Null until a server
     * that sends them has answered.
     */
    val remoteActivityDays: List<String>? = null,
    /**
     * When the server's log was last pulled for this account; null until the
     * first pull lands — the journal isn't hydrated before then.
     */
    @Serializable(with = InstantAsStringSerializer::class)
    val lastPulledAt: Instant? = null,
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

  /** Whether the server's log has been pulled for this account at least once —
   * until then the rhythm is only this install's partial memory. */
  val isHydrated: Boolean get() = _state.value.lastPulledAt != null

  /** Whether any finished session hasn't reached the server yet. */
  val hasUnsynced: Boolean get() = _state.value.completions.any { !it.isSynced }

  fun currentStreakDays(): Int = PracticeMath.currentStreakDays(completions, zone, clock, otherPracticeDays())

  fun longestStreakDays(): Int = PracticeMath.longestStreakDays(completions, zone, otherPracticeDays())

  /** Whether a Global Pause the server counted (an eligible claim) was sat
   * today — the same marker the rhythm reads. iOS's `hasSatGlobalPauseToday`. */
  fun hasSatGlobalPauseToday(): Boolean = PracticeMath.hasPauseDay(pauseDays(), zone, clock)

  /**
   * Whether today's reminder should rest: today's goal met in DEEP Session
   * minutes, or a Global Pause sat today. The one rule every reminder
   * evaluation reads (iOS's `reminderRestsToday`, PR #62). A finished sound
   * keeps the rhythm but does not rest the reminder.
   */
  fun reminderRestsToday(): Boolean = minutesToday() >= dailyGoalMinutes || hasSatGlobalPauseToday()

  /** The rhythm across today's boundary — what every ending reads. */
  fun continuityTransition(): ContinuityTransition =
    PracticeMath.continuityTransition(completions, zone, clock, otherPracticeDays())

  private fun pauseDays(): Set<LocalDate> = PracticeMath.days(_state.value.pauseDays)

  /** Every day kept by practice that isn't a session: pause nights and
   * finished sounds marked here, and the server's activity days. */
  private fun otherPracticeDays(): Set<LocalDate> {
    val state = _state.value
    return PracticeMath.days(state.pauseDays + state.trackDays + state.remoteActivityDays.orEmpty())
  }

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
   * Keeps [at]'s local day in the rhythm — the server counted tonight's Global
   * Pause attendance. One marker a day is all the rhythm reads; markers older
   * than [PAUSE_DAY_RETENTION_DAYS] are dropped as a new one lands.
   *
   * Ported from iOS's `recordActivity(.pause, at:)`. Local only: the server
   * keeps its own record of the attendance.
   */
  suspend fun recordPauseDay(at: Instant) {
    recordDay(at, read = { it.pauseDays }, write = { state, days -> state.copy(pauseDays = days) })
  }

  /**
   * Keeps [at]'s local day in the rhythm — a sound played through to its end
   * then. Recorded before the listen is reported, so the day counts whatever
   * the server says about the heart, offline included. It does not rest the
   * reminder ([reminderRestsToday]).
   *
   * Ported from iOS's `recordActivity(.track, at:)`.
   */
  suspend fun recordTrackDay(at: Instant) {
    recordDay(at, read = { it.trackDays }, write = { state, days -> state.copy(trackDays = days) })
  }

  /**
   * Adds [at]'s local day to one list of day markers — one marker a day is
   * all the rhythm reads — dropping markers older than
   * [PAUSE_DAY_RETENTION_DAYS] as it lands.
   */
  private suspend fun recordDay(
    at: Instant,
    read: (State) -> List<String>,
    write: (State, List<String>) -> State,
  ) {
    restore()
    val key = at.atZone(zone).toLocalDate().toString()
    val changed = synchronized(lock) {
      val state = _state.value
      val days = read(state)
      if (key in days) return@synchronized false
      val cutoff = clock.instant().atZone(zone).toLocalDate().minusDays(PAUSE_DAY_RETENTION_DAYS)
      val kept = days.filter { existing -> PracticeMath.day(existing)?.isBefore(cutoff) == false }
      touched = true
      _state.value = write(state, kept + key)
      true
    }
    if (changed) persist()
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
   * removed. Takes the server's activity days, and marks the journal
   * hydrated. Errors are swallowed; the local journal is already whole.
   */
  suspend fun pull() {
    restore()
    val stamp = synchronized(lock) { generation }
    val log = try {
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
      val unseen = log.completions
        .filter { it.id !in known }
        .distinctBy { it.id }
        .map { it.copy(isSynced = true) }
      touched = true
      _state.value = state.copy(
        completions = if (unseen.isEmpty()) {
          state.completions
        } else {
          (state.completions + unseen).sortedBy { it.completedAt }
        },
        // An older server omits the field — keep what we had rather than forget.
        remoteActivityDays = log.activityDays ?: state.remoteActivityDays,
        lastPulledAt = clock.instant(),
      )
      true
    }
    if (merged) persist()
  }

  /**
   * Waits — at most [timeout] — for the journal's first pull, starting one if
   * it hasn't happened. An ending calls this before reading the rhythm, so it
   * shows the account's real one rather than this install's partial memory (a
   * fresh sign-in would otherwise read 0 → 1).
   *
   * Any pull landing ends the wait — this one, or the launch's own sync
   * already in flight. Unlike iOS, this call's pull is cancelled with the
   * wait rather than left to land on its own; the next foreground sync pulls
   * again.
   */
  suspend fun awaitHydration(timeout: Duration) {
    restore()
    if (isHydrated) return
    withTimeoutOrNull(timeout.toMillis()) {
      coroutineScope {
        val pulling = launch { pull() }
        _state.first { it.lastPulledAt != null }
        pulling.cancel()
      }
    }
  }

  /**
   * Offers unsynced sessions to the server, giving up after [timeout]. True
   * when nothing is left unsynced — log out asks this while the token still
   * works, and asks the member before dropping anything.
   */
  suspend fun flushPending(timeout: Duration): Boolean {
    restore()
    if (!hasUnsynced) return true
    withTimeoutOrNull(timeout.toMillis()) { push() }
    return !hasUnsynced
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

    /** How long a pause or track day marker is kept — well past any rhythm
     * the garden shows, and the server's `activityDays` window. */
    const val PAUSE_DAY_RETENTION_DAYS = 400L
  }
}
