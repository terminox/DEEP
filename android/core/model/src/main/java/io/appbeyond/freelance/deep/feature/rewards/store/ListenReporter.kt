package io.appbeyond.freelance.deep.feature.rewards.store

import io.appbeyond.freelance.deep.auth.HttpStatusCarrying
import io.appbeyond.freelance.deep.feature.rewards.model.AwardCap
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.feature.rewards.model.ListenOutcome
import io.appbeyond.freelance.deep.feature.rewards.model.RewardRules
import io.appbeyond.freelance.deep.shared.persistence.BlobStoring
import io.appbeyond.freelance.deep.shared.persistence.InstantAsStringSerializer
import io.appbeyond.freelance.deep.shared.persistence.StoreJson
import io.appbeyond.freelance.deep.shared.persistence.readOrNull
import io.appbeyond.freelance.deep.shared.persistence.writeQuietly
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
import kotlinx.coroutines.job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import java.util.concurrent.atomic.AtomicLong

/**
 * A brief word from the listen reporter for the player chrome: a heart just
 * landed, or today's track hearts are all in.
 *
 * Ported from `ListenNotice` in Deep/Deep/Features/Rewards/ListenReporter.swift.
 * [id] tells one showing of a notice from the next, so a surface reacts to a
 * new heart even when its kind repeats.
 */
data class ListenNotice(val id: Long, val kind: Kind) {
  sealed interface Kind {
    /** This listen earned its heart. */
    data object Earned : Kind

    /** Today's track hearts are all in. */
    data class DayComplete(val perDay: Int) : Kind
  }
}

/**
 * The seam between finished tracks and the hearts they earn. The player
 * chrome depends on this so previews run against [MockListenReporter] (the
 * `SoundPlaying` pattern).
 */
interface ListenReporting {
  /** What the player chrome should say right now; null most of the time. */
  val notice: StateFlow<ListenNotice?>

  /** Whether any finished track (still inside the server's window) is waiting to reach the server. */
  val hasPending: Boolean

  /**
   * Notes a track played through to its end at [finishedAt]: keeps the day in
   * the member's rhythm, queues the report, and offers it to the server.
   */
  suspend fun record(trackId: String, finishedAt: Instant)

  /** Offers every queued listen to the server, one at a time. */
  suspend fun flush()

  /** Flushes, waiting at most [timeout]. True when nothing is left queued. */
  suspend fun flush(timeout: Duration): Boolean

  /** Forgets the queue and today's notices — log out and account deletion. */
  suspend fun reset()

  /**
   * Whether a surface showing [notice] should play its haptic: true for the
   * first to ask, so the heart is felt once however many surfaces show it.
   */
  fun claimHaptic(notice: ListenNotice): Boolean
}

/**
 * The durable listen report. A finished track is queued on disk before
 * anything touches the network, so a dropped connection, a 5xx or an expired
 * session costs nothing: the queue is retried on launch, sign-in and every
 * return to the foreground until the server answers (or the listen is too old
 * to count — the server's 48h window).
 *
 * Reports go out serially, oldest first, and carry their finish time, so a
 * heart earned offline lands on the day it was earned. Every grant is handed
 * to [awardSink] — the shared ingest — so the ledger and garden reconcile.
 *
 * Ported from Deep/Deep/Features/Rewards/ListenReporter.swift. The queue and the
 * once-a-day stamp persist apart, as iOS keeps them under two `UserDefaults`
 * keys (`deep.sound.pendingListens`, `deep.sound.dayCompleteNoticed`):
 *
 * ```
 * [{"id":"…","trackId":"rain","completedAt":"2026-10-31T05:00:00Z"}]
 * {"noticedAt":"2026-10-31T05:00:04Z"}
 * ```
 *
 * Differences from iOS:
 * - [record] suspends while the listen is written down; the service's
 *   finish callback launches it on the app scope.
 * - DIVERGENCE: a 403 ends a listen's retries along with 400 and 404 (see
 *   [isFinal]). The server answers 403 `premium_locked` for a track this
 *   member was never given; iOS keeps such a listen at the head of the queue,
 *   where it stops every later listen from reaching the server for 48 hours.
 * - The VoiceOver announcement is not made here: the shell's live region
 *   speaks [notice] as it changes.
 *
 * @param report sends one listen. Throws on anything but an answer; a 2xx the
 *   app couldn't read comes back as [ListenOutcome.Unjudged].
 * @param recordActivity keeps a finish's day in the practice rhythm.
 * @param scope process-lifetime: background flushes and notice timers run here.
 */
class ListenReporter(
  private val report: suspend (trackId: String, completedAt: Instant) -> ListenOutcome,
  private val recordActivity: suspend (at: Instant) -> Unit,
  private val queueBlob: BlobStoring,
  private val stampBlob: BlobStoring,
  private val scope: CoroutineScope,
  private val clock: Clock,
  private val zone: ZoneId,
  private val noticeDuration: Duration = NOTICE_DURATION,
) : ListenReporting {

  /** One finished track waiting for the server. */
  @Serializable
  internal data class PendingListen(
    val id: String,
    val trackId: String,
    @Serializable(with = InstantAsStringSerializer::class)
    val completedAt: Instant,
  )

  /** When today's hearts were last said to be in. */
  @Serializable
  private data class Stamp(
    @Serializable(with = InstantAsStringSerializer::class)
    val noticedAt: Instant? = null,
  )

  /** Settled grants land here — the app points this at the shared ingest. */
  @Volatile
  var awardSink: (suspend (AwardGrant) -> Unit)? = null

  private val _notice = MutableStateFlow<ListenNotice?>(null)
  override val notice: StateFlow<ListenNotice?> = _notice.asStateFlow()

  /** Guards every field below. Never held across a suspension. */
  private val lock = Any()

  private var pending: List<PendingListen> = emptyList()

  private var dayCompleteNoticedAt: Instant? = null

  /** Bumped by [reset]. An answer that started under an earlier generation
   * belongs to the signed-out account and is dropped. */
  private var generation = 0L

  /** Notices waiting their turn behind the one on screen. */
  private val upcoming = ArrayDeque<ListenNotice.Kind>()

  private var expiry: Job? = null

  /** The last notice whose haptic was played. */
  private var feltNoticeId: Long? = null

  private val noticeIds = AtomicLong()

  /** The flush under way, so a second caller joins it instead of racing it. */
  private var flushJob: Job? = null

  /** Set when a flush is asked for mid-flush: the running one goes round once
   * more so listens queued meanwhile aren't left behind. */
  private var flushAgain = false

  private val restoreLock = Mutex()

  @Volatile
  private var restored = false

  private val persistLock = Mutex()

  /** Every listen still queued, oldest first — tests read it. */
  internal val queued: List<PendingListen> get() = synchronized(lock) { pending }

  override val hasPending: Boolean
    get() {
      val cutoff = clock.instant().minus(RETENTION)
      return synchronized(lock) { pending.any { !it.completedAt.isBefore(cutoff) } }
    }

  /**
   * Adopts the persisted queue and stamp, once. Every suspending member calls
   * this first; calling it eagerly at launch only warms it.
   */
  suspend fun restore() {
    if (restored) return
    restoreLock.withLock {
      if (restored) return
      val queue = queueBlob.readOrNull()?.let { json ->
        runCatching { StoreJson.decodeFromString(ListSerializer(PendingListen.serializer()), json) }.getOrNull()
      }
      val stamp = stampBlob.readOrNull()?.let { json ->
        runCatching { StoreJson.decodeFromString(Stamp.serializer(), json) }.getOrNull()
      }
      synchronized(lock) {
        pending = queue.orEmpty()
        dayCompleteNoticedAt = stamp?.noticedAt
      }
      restored = true
    }
  }

  // MARK: - ListenReporting

  override suspend fun record(trackId: String, finishedAt: Instant) {
    restore()
    withContext(NonCancellable) {
      // A track played to its end keeps the day, whatever the server says
      // about the heart.
      recordActivity(finishedAt)
      // The server credits a track once per day; a second finish of the same
      // track that day has nothing to earn, so it isn't queued twice.
      val day = finishedAt.localDate()
      val added = synchronized(lock) {
        if (pending.any { it.trackId == trackId && it.completedAt.localDate() == day }) {
          false
        } else {
          pending = pending + PendingListen(UUID.randomUUID().toString(), trackId, finishedAt)
          true
        }
      }
      if (added) persistQueue()
    }
    startFlush()
  }

  override suspend fun flush() {
    startFlush().join()
  }

  override suspend fun flush(timeout: Duration): Boolean {
    restore()
    if (!hasPending) return true
    // The flush runs on the reporter's own scope, so a report outliving the
    // timeout still lands rather than being torn down mid-request.
    val running = startFlush()
    withTimeoutOrNull(timeout.toMillis()) { running.join() }
    return !hasPending
  }

  override fun claimHaptic(notice: ListenNotice): Boolean = synchronized(lock) {
    if (feltNoticeId == notice.id) return@synchronized false
    feltNoticeId = notice.id
    true
  }

  override suspend fun reset() {
    restore()
    withContext(NonCancellable) {
      synchronized(lock) {
        generation++
        pending = emptyList()
        dayCompleteNoticedAt = null
        upcoming.clear()
        expiry?.cancel()
        expiry = null
        _notice.value = null
      }
      persistQueue()
      persistLock.withLock { stampBlob.writeQuietly(null) }
    }
  }

  // MARK: - Flush

  /**
   * The running flush, or a new one on [scope]. Started lazily, once it is
   * recorded as the running one, so even an immediate dispatcher can't finish
   * it before a second caller can find it.
   */
  private fun startFlush(): Job {
    var fresh = false
    val job = synchronized(lock) {
      flushJob?.also { flushAgain = true } ?: scope.launch(start = CoroutineStart.LAZY) {
        val self = coroutineContext.job
        try {
          runFlush()
        } finally {
          synchronized(lock) { if (flushJob === self) flushJob = null }
        }
      }.also {
        flushJob = it
        fresh = true
      }
    }
    if (fresh) job.start()
    return job
  }

  private suspend fun runFlush() {
    try {
      restore()
      do {
        synchronized(lock) { flushAgain = false }
        drain()
      } while (synchronized(lock) { flushAgain && pending.isNotEmpty() })
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (_: Exception) {
      // Nothing may reach the app scope. The queue is on disk; the next flush
      // tries again.
    }
  }

  /**
   * Sends the queue oldest first. An answer — any 2xx, or a 400/403/404 the
   * listen can never get past — removes the entry; anything that may pass
   * (offline, a 5xx, an expired session) stops the drain and keeps the rest
   * for the next flush.
   */
  private suspend fun drain() {
    prune()
    val stamp = synchronized(lock) { generation }
    for (entry in synchronized(lock) { pending }) {
      val live = synchronized(lock) { generation == stamp && pending.any { it.id == entry.id } }
      if (!live) return
      val outcome = try {
        report(entry.trackId, entry.completedAt)
      } catch (cancelled: CancellationException) {
        throw cancelled
      } catch (failure: Exception) {
        if (!isFinal(failure) || !remove(entry, stamp)) return
        continue
      }
      if (!remove(entry, stamp)) return
      settle(entry, outcome, stamp)
    }
  }

  /** Takes [entry] off the queue, on disk too. False when a reset came first. */
  private suspend fun remove(entry: PendingListen, stamp: Long): Boolean = withContext(NonCancellable) {
    val current = synchronized(lock) {
      if (generation != stamp) return@synchronized false
      pending = pending.filterNot { it.id == entry.id }
      true
    }
    if (current) persistQueue()
    current
  }

  /** Drops listens the server would no longer place. */
  private suspend fun prune() {
    val cutoff = clock.instant().minus(RETENTION)
    val pruned = synchronized(lock) {
      if (pending.none { it.completedAt.isBefore(cutoff) }) return@synchronized false
      pending = pending.filterNot { it.completedAt.isBefore(cutoff) }
      true
    }
    if (pruned) persistQueue()
  }

  // MARK: - Settling

  private suspend fun settle(entry: PendingListen, outcome: ListenOutcome, stamp: Long) {
    val grant = outcome.grant
    if (grant != null && isCurrent(stamp)) awardSink?.invoke(grant)
    // An unjudged listen (too old to place) has nothing to say.
    if (!outcome.judged) return

    // Only a listen from today, answered while the member is plausibly still
    // there, gets a word in the chrome.
    val now = clock.instant()
    if (entry.completedAt.localDate() != now.localDate()) return
    if (Duration.between(entry.completedAt, now) > NOTICE_WINDOW) return

    val perDay = outcome.tally?.perDay ?: RewardRules.trackDailyLimit
    if (outcome.granted) {
      present(ListenNotice.Kind.Earned, stamp)
      if (outcome.tally?.isComplete == true) presentDayComplete(perDay, stamp)
    } else if (outcome.cappedBy == AwardCap.KIND_CAP) {
      presentDayComplete(perDay, stamp)
    }
    // A duplicate and the daily cap stay silent: nothing new happened.
  }

  /** Today's hearts being in is said once a day, however many listens follow. */
  private suspend fun presentDayComplete(perDay: Int, stamp: Long) {
    val now = clock.instant()
    val fresh = synchronized(lock) {
      if (generation != stamp) return@synchronized false
      if (dayCompleteNoticedAt?.localDate() == now.localDate()) return@synchronized false
      dayCompleteNoticedAt = now
      true
    }
    if (!fresh) return
    withContext(NonCancellable) {
      persistLock.withLock {
        stampBlob.writeQuietly(StoreJson.encodeToString(Stamp.serializer(), Stamp(now)))
      }
    }
    present(ListenNotice.Kind.DayComplete(perDay), stamp)
  }

  // MARK: - Notices

  private fun present(kind: ListenNotice.Kind, stamp: Long) = synchronized(lock) {
    if (generation != stamp) return@synchronized
    upcoming.addLast(kind)
    if (_notice.value == null) advanceLocked()
  }

  /**
   * Retires the notice on screen and shows the next one waiting, if any. The
   * expiry timer calls this; tests call it to step through a sequence.
   */
  fun advanceNotice() = synchronized(lock) { advanceLocked() }

  private fun advanceLocked() {
    expiry?.cancel()
    expiry = null
    val kind = upcoming.removeFirstOrNull()
    if (kind == null) {
      _notice.value = null
      return
    }
    val shown = ListenNotice(noticeIds.incrementAndGet(), kind)
    _notice.value = shown
    expiry = scope.launch {
      delay(noticeDuration.toMillis())
      // Only the notice this timer was set for: one advanced by hand meanwhile
      // has its own timer.
      synchronized(lock) { if (_notice.value?.id == shown.id) advanceLocked() }
    }
  }

  // MARK: - Internals

  private fun isCurrent(stamp: Long): Boolean = synchronized(lock) { generation == stamp }

  private fun Instant.localDate(): LocalDate = atZone(zone).toLocalDate()

  /** Writes the queue as it stands; an empty queue removes the blob. */
  private suspend fun persistQueue() = withContext(NonCancellable) {
    persistLock.withLock {
      val queue = synchronized(lock) { pending }
      queueBlob.writeQuietly(
        if (queue.isEmpty()) null else StoreJson.encodeToString(ListSerializer(PendingListen.serializer()), queue),
      )
    }
  }

  companion object {
    /** The server places a listen up to 48h back; older ones never count. */
    val RETENTION: Duration = Duration.ofHours(48)

    /**
     * A notice only speaks for a listen answered this soon after it finished —
     * a heart surfacing hours later, mid-something-else, would read as noise.
     */
    val NOTICE_WINDOW: Duration = Duration.ofMinutes(10)

    /** How long each notice holds the subtitle line. */
    val NOTICE_DURATION: Duration = Duration.ofSeconds(4)

    /**
     * The statuses a listen can never get past, so retrying is pointless: 400,
     * the server rejected the report's shape; 403, the track is DEEP Premium
     * and locked for this member; 404, the track is gone. Everything else —
     * offline, a 401 mid-refresh, a 429, a 5xx — may pass next time.
     */
    private val FINAL_STATUSES = setOf(400, 403, 404)

    /** Whether a failed report can never succeed. */
    fun isFinal(error: Exception): Boolean = (error as? HttpStatusCarrying)?.status in FINAL_STATUSES
  }
}

// MARK: - Mock

/**
 * In-memory [ListenReporting] for previews: shows [notice] and remembers what
 * was recorded. Never wired by the shipped app.
 */
class MockListenReporter(
  notice: ListenNotice.Kind? = null,
  override val hasPending: Boolean = false,
) : ListenReporting {

  override val notice: StateFlow<ListenNotice?> = MutableStateFlow(notice?.let { ListenNotice(1, it) })

  /** Every listen recorded, newest last. */
  val recorded = mutableListOf<Pair<String, Instant>>()

  private var feltNoticeId: Long? = null

  override suspend fun record(trackId: String, finishedAt: Instant) {
    recorded += trackId to finishedAt
  }

  override suspend fun flush() {}

  override suspend fun flush(timeout: Duration): Boolean = !hasPending

  override suspend fun reset() {}

  override fun claimHaptic(notice: ListenNotice): Boolean {
    if (feltNoticeId == notice.id) return false
    feltNoticeId = notice.id
    return true
  }

  companion object {
    /** Showing "+1 heart". */
    fun earned() = MockListenReporter(ListenNotice.Kind.Earned)

    /** Showing that today's track hearts are all in. */
    fun dayComplete() = MockListenReporter(ListenNotice.Kind.DayComplete(RewardRules.trackDailyLimit))
  }
}
