package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.auth.isTransportFailure
import io.appbeyond.freelance.deep.feature.globalpause.model.GlobalPauseCardState
import io.appbeyond.freelance.deep.feature.globalpause.model.LoungeBroadcast
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseLiveSnapshot
import io.appbeyond.freelance.deep.feature.globalpause.model.PausePhaseKey
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseSchedule
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessage
import io.appbeyond.freelance.deep.feature.globalpause.model.PostedPeaceMessage
import io.appbeyond.freelance.deep.feature.globalpause.model.SyncedClock
import io.appbeyond.freelance.deep.feature.globalpause.model.loungeBroadcast
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import java.time.Duration
import java.time.Instant

/**
 * Everything the Global Pause screens read, as one value: the occurrence in
 * hand, whether its meditation is live, what the card shows, the room, and
 * the night's awards.
 *
 * @property pauseAward tonight's settled attendance award. Deliberately *not*
 *   cleared by [GlobalPauseSession.leaveSession]: the reflection handback
 *   releases presence while the ending — the award's one reader — is still up,
 *   and the claim may still be in flight. Cleared as the next visit begins.
 * @property pauseAwardMissed the server answered tonight's claim with
 *   `eligible: false` — left early or joined late — so the ending can say why
 *   no hearts came rather than calling the day full.
 * @property pauseAwardPending the claim has gone out without an answer — still
 *   in flight, or given up on. The ending then claims neither the hearts nor a
 *   full day. A late answer still lands and clears it.
 * @property messageAward the first peace message of the night's award.
 * @property postedMessage tonight's own message, kept so the lounge can seat it
 *   at the head of a feed fetched before it existed.
 */
data class GlobalPauseState(
  val schedule: PauseSchedule? = null,
  val isMeditationLive: Boolean = false,
  val isFukuOnAir: Boolean = false,
  val cardState: GlobalPauseCardState = GlobalPauseCardState.Off(next = null),
  val participantCount: Int = 0,
  val participantsByCountry: Map<String, Int> = emptyMap(),
  val participantsByContinent: Map<String, Int> = emptyMap(),
  val participantLocations: List<PauseLiveSnapshot.GeoPoint> = emptyList(),
  val unlocatedByCountry: Map<String, Int> = emptyMap(),
  val myLocation: PauseJoinPoint? = null,
  val pauseAward: AwardGrant? = null,
  val pauseAwardMissed: Boolean = false,
  val pauseAwardPending: Boolean = false,
  val messageAward: AwardGrant? = null,
  val postedMessage: PeaceMessage? = null,
)

/**
 * The Global Pause engine: holds the resolved occurrence, tracks whether its
 * meditation is live against the synced clock (flipping at exact window
 * boundaries), and scopes the live presence and polling loops to the time the
 * session screen is open.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Session/GlobalPauseSession.swift.
 * App-lifetime, because the Home card and the lounge need the schedule long
 * before a session is ever opened.
 *
 * **Threading.** Like the `@MainActor` original, every member must be called
 * from one thread, and [scope] must run on it — the app hands it a
 * `Dispatchers.Main.immediate` scope. Nothing here locks.
 *
 * **Cadence.** Presence renews every [heartbeatInterval] (10s, iOS's current
 * value — short enough that one dropped beat costs the server's coverage rule
 * little) and the room is polled every [pollInterval] (5s), while a session is
 * entered.
 *
 * **Backgrounding** — Android's mechanics, iOS's outcome. On iOS the meditation
 * plays through background audio, which keeps the process — and so the
 * heartbeats — alive with the screen locked. Android keeps the heartbeats
 * running in the background too (the meditation runs under a foreground
 * service), but [onBackground] parks the 5s live poll, which only feeds what is
 * on screen; [onForeground] resumes it and re-resolves the schedule, which also
 * re-syncs the clock — iOS's `willEnterForeground` refresh.
 *
 * @param presenceId one stable anonymous identity per install, so reopening the
 *   session never double-counts (the server keys signed-in members by user id).
 * @param countryIso the device's region as ISO alpha-2, or null — see
 *   [io.appbeyond.freelance.deep.feature.globalpause.model.PauseCountry].
 * @param countryCentroid where a country sits, for joins the server couldn't
 *   locate and the first guess at the member's own location. The globe's
 *   country table arrives with the Earth renderer (week 7); until then joins
 *   without coordinates are skipped and the location waits for the first
 *   heartbeat.
 * @param introDuration the bundled intro clip's length, read once. It decides
 *   where Fuku's set hands off to the music, and so when the broadcast ends.
 * @param awardSink where settled awards (the attendance claim, the first peace
 *   message) are handed — the app's shared award ingest.
 * @param activitySink told when the server counts tonight's attendance, so an
 *   attended pause keeps the day in the member's rhythm.
 * @param claimRetryDelays the pauses between claim attempts — one at once, then
 *   backing off. Injectable so tests needn't sit through the real waits.
 */
class GlobalPauseSession(
  val clock: SyncedClock,
  private val remote: PauseEventRemote,
  private val scope: CoroutineScope,
  private val presenceId: suspend () -> String,
  private val countryIso: () -> String?,
  private val countryCentroid: (String) -> PauseJoinPoint? = { null },
  private val introDuration: suspend () -> Duration = { Duration.ZERO },
  private val awardSink: (suspend (AwardGrant) -> Unit)? = null,
  private val activitySink: (suspend (Instant) -> Unit)? = null,
  private val claimRetryDelays: List<Duration> = DEFAULT_CLAIM_RETRY_DELAYS,
  private val heartbeatInterval: Duration = HEARTBEAT_INTERVAL,
  private val pollInterval: Duration = POLL_INTERVAL,
) {

  private val _state = MutableStateFlow(GlobalPauseState())
  val state: StateFlow<GlobalPauseState> = _state.asStateFlow()

  private val _joins = MutableSharedFlow<List<PauseJoinPoint>>(
    extraBufferCapacity = JOIN_BUFFER,
    onBufferOverflow = BufferOverflow.DROP_OLDEST,
  )

  /**
   * Joins that arrived since the last poll, one batch per poll, minus the
   * member's own — the session screen flares that itself as the globe lands
   * on them. Not replayed: a screen that subscribes late sees only new
   * arrivals, which is what a spark means.
   */
  val joins: SharedFlow<List<PauseJoinPoint>> = _joins.asSharedFlow()

  private var measuredIntro: Duration = Duration.ZERO
  private var hasMeasuredIntro = false
  private var boundaryJob: Job? = null

  /** The window end already gone back to the server for; see [armBoundaryTimer]. */
  private var refetchedWindowEnd: Instant? = null
  private var heartbeatJob: Job? = null
  private var pollJob: Job? = null
  private var claimJob: Job? = null
  private var isInBackground = false

  /** Joins already turned into sparks, so a poll never replays old ones. */
  private val seenJoins = HashSet<String>()

  /**
   * The member's own join comes back in the feed like anyone else's — but the
   * session screen already flares it as the globe lands on them. Swallow that
   * echo once so their city doesn't spark twice.
   */
  private var hasSwallowedOwnJoin = false

  // MARK: - Derived

  /** When the next meditation begins — the card's countdown target. */
  val nextMeditationStart: Instant?
    get() = _state.value.schedule?.nextMeditationStart(clock.now())

  /** Seconds into the meditation stream at the synced clock's now. */
  val meditationElapsed: Duration
    get() {
      val start = _state.value.schedule?.window(PausePhaseKey.Meditation)?.startsAt
        ?: return Duration.ZERO
      return maxOf(Duration.ZERO, Duration.between(start, clock.now()))
    }

  val meditationDuration: Duration
    get() = _state.value.schedule?.meditationDuration ?: Duration.ZERO

  /** This occurrence's lounge set, once the schedule has landed. Null when
   * there is nothing to broadcast. */
  val loungeBroadcast: LoungeBroadcast?
    get() = _state.value.schedule?.loungeBroadcast(measuredIntro)

  /** Whether a session is entered — presence is being renewed. */
  val isInSession: Boolean get() = heartbeatJob != null

  // MARK: - Lifecycle

  /**
   * Fetches the schedule and starts tracking window boundaries. Safe to call
   * again — on foreground, on a pull to refresh, as the lounge opens — it
   * simply re-resolves.
   */
  suspend fun start() {
    if (!hasMeasuredIntro) {
      hasMeasuredIntro = true
      measuredIntro = introDuration()
    }
    refreshSchedule()
  }

  /**
   * The app came back. A suspended or frozen process held its timers mid-count,
   * so recompute from the server's clock, and resume the live poll if a
   * session is open.
   */
  fun onForeground() {
    isInBackground = false
    scope.launch { refreshSchedule() }
    if (isInSession && pollJob == null) startPolling()
  }

  /** The app left. The room's poll only feeds the screen, so it rests. */
  fun onBackground() {
    isInBackground = true
    pollJob?.cancel()
    pollJob = null
  }

  private suspend fun refreshSchedule() {
    try {
      val fetched = remote.schedule()
      _state.update { it.copy(schedule = fetched) }
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (_: Exception) {
      // Keep whatever schedule we had; the boundary loop keeps working off it
      // (and retries on its own when there's no schedule at all).
    }
    recomputeState()
    armBoundaryTimer()
  }

  private fun recomputeState() {
    val schedule = _state.value.schedule
    val window = schedule?.window(PausePhaseKey.Meditation)
    if (schedule == null || window == null) {
      _state.update {
        it.copy(isMeditationLive = false, isFukuOnAir = false, cardState = GlobalPauseCardState.Off(null))
      }
      return
    }
    val now = clock.now()
    val live = !now.isBefore(window.startsAt) && now.isBefore(window.endsAt)
    val onAir = schedule.loungeBroadcast(measuredIntro)?.isOnAir(now) ?: false
    val card = when {
      live -> GlobalPauseCardState.Live
      else -> {
        val target = schedule.nextMeditationStart(now)
        when {
          target == null -> GlobalPauseCardState.Off(null)
          Duration.between(now, target) <= COUNTDOWN_LEAD -> GlobalPauseCardState.Countdown(target)
          else -> GlobalPauseCardState.Off(target)
        }
      }
    }
    // StateFlow drops an equal value, so an unchanged recompute — the live
    // poll runs one every few seconds — wakes nothing.
    _state.update { it.copy(isMeditationLive = live, isFukuOnAir = onAir, cardState = card) }
  }

  /**
   * The next instant anything on screen can change: the next phase boundary,
   * the countdown start (meditation − lead), or the moment Fuku's set signs off.
   * Null keeps the 60s retry path (no schedule, or window over).
   */
  private fun nextStateBoundary(now: Instant): Instant? {
    val schedule = _state.value.schedule ?: return null
    val phaseBoundary = schedule.nextBoundary(now) ?: return null
    val candidates = mutableListOf(phaseBoundary)
    schedule.nextMeditationStart(now)?.let { next ->
      val countdownStart = next.minus(COUNTDOWN_LEAD)
      if (countdownStart.isAfter(now)) candidates += countdownStart
    }
    // The set ends partway through the lobby phase, so its end is not a phase
    // boundary of its own — without it ON AIR would stay lit to the welcome.
    schedule.loungeBroadcast(measuredIntro)?.endsAt?.let { if (it.isAfter(now)) candidates += it }
    return candidates.min()
  }

  /**
   * One sleeping job per upcoming boundary, re-armed after every firing and
   * clock sync. An occurrence that is over is re-fetched rather than waited
   * out, because only the server knows what comes next.
   *
   * The re-fetch is latched on the spent window's own end, which keeps a
   * server that keeps handing back the same finished occurrence from becoming
   * a zero-backoff request loop: a fetch landing a new occurrence moves the
   * window end and re-arms the latch for free, while one landing the same
   * occurrence — or failing, which keeps the old one on purpose — falls
   * through to the 60s sleep. Cost of a misbehaving server: one extra request.
   */
  private fun armBoundaryTimer() {
    boundaryJob?.cancel()
    val now = clock.now()

    val windowEnd = _state.value.schedule?.windowEnd
    if (windowEnd != null && !now.isBefore(windowEnd) && refetchedWindowEnd != windowEnd) {
      refetchedWindowEnd = windowEnd
      boundaryJob = scope.launch { refreshSchedule() }
      return
    }

    val boundary = nextStateBoundary(now)
    if (boundary == null) {
      boundaryJob = scope.launch {
        delay(NO_SCHEDULE_RETRY.toMillis())
        refreshSchedule()
      }
      return
    }

    // A live boundary means the occurrence in hand is current again.
    refetchedWindowEnd = null
    val wait = maxOf(Duration.between(now, boundary), MIN_BOUNDARY_WAIT)
    boundaryJob = scope.launch {
      delay(wait.toMillis())
      recomputeState()
      armBoundaryTimer()
    }
  }

  // MARK: - Session scope (presence + live polling)

  /** Starts heartbeats and live polling. Called as the session screen opens. */
  fun enterSession() {
    if (heartbeatJob != null) return
    // A fresh visit must not greet tonight's reflection with a stale award from
    // an earlier night — forget it (and any orphaned claim) here rather than on
    // leave, which runs mid-reflection.
    claimJob?.cancel()
    claimJob = null
    val country = countryIso()
    _state.update { state ->
      state.copy(
        pauseAward = null,
        pauseAwardMissed = false,
        pauseAwardPending = false,
        messageAward = null,
        postedMessage = null,
        // The country centroid at once, so the globe can turn to *somewhere*
        // the moment the screen lands; the first heartbeat overwrites it.
        myLocation = state.myLocation ?: country?.let(countryCentroid),
      )
    }

    heartbeatJob = scope.launch {
      while (isActive) {
        try {
          val resolved = remote.heartbeat(presenceId(), country)
          if (resolved != null) _state.update { it.copy(myLocation = resolved) }
        } catch (cancelled: CancellationException) {
          throw cancelled
        } catch (_: Exception) {
          // One dropped beat costs the coverage rule little; the next one comes.
        }
        delay(heartbeatInterval.toMillis())
      }
    }
    if (!isInBackground) startPolling()
  }

  private fun startPolling() {
    pollJob = scope.launch {
      while (isActive) {
        pollLive()
        delay(pollInterval.toMillis())
      }
    }
  }

  /** Ends presence: the loops stop, and the server is told (best-effort). */
  fun leaveSession() {
    heartbeatJob?.cancel()
    heartbeatJob = null
    pollJob?.cancel()
    pollJob = null
    seenJoins.clear()
    hasSwallowedOwnJoin = false
    _state.update { it.copy(myLocation = null) }
    scope.launch {
      try {
        remote.leave(presenceId())
      } catch (cancelled: CancellationException) {
        throw cancelled
      } catch (_: Exception) {
        // The server sweeps stale presence within a minute anyway.
      }
    }
  }

  private suspend fun pollLive() {
    val snapshot = try {
      remote.live()
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (_: Exception) {
      return
    }

    val me = _state.value.myLocation
    val fresh = mutableListOf<PauseJoinPoint>()
    for (join in snapshot.recentJoins) {
      val key = "${join.iso}-${join.at.toEpochMilli()}"
      if (!seenJoins.add(key)) continue
      val point = if (join.lat != null && join.lon != null) {
        PauseJoinPoint(join.lat, join.lon)
      } else {
        // The server couldn't place the IP — land it on the country centroid.
        countryCentroid(join.iso) ?: continue
      }
      // Exact by construction: a located join carries the very coordinates the
      // heartbeat resolved into `myLocation`.
      if (!hasSwallowedOwnJoin && point == me) {
        hasSwallowedOwnJoin = true
        continue
      }
      fresh += point
    }

    _state.update {
      it.copy(
        participantCount = snapshot.participantCount,
        participantsByCountry = snapshot.byCountry,
        participantsByContinent = snapshot.byContinent,
        participantLocations = snapshot.locations,
        unlocatedByCountry = snapshot.unlocatedByCountry,
      )
    }
    if (fresh.isNotEmpty()) _joins.tryEmit(fresh)

    // A clock sync can move a boundary; keep the timer honest.
    recomputeState()
    armBoundaryTimer()
  }

  // MARK: - Awards

  /**
   * Claims tonight's attendance award — called as the reflection begins.
   * Always claims; the server judges eligibility, so an ineligible claim
   * resolves to no grant and marks [GlobalPauseState.pauseAwardMissed].
   *
   * A closing heartbeat goes first, so the meditation's last seconds are on
   * the server's books before it judges them. The claim is retried while the
   * network is the problem — a blip at the end must not cost the night — and
   * never once the server has answered.
   */
  fun claimPauseAward() {
    if (_state.value.pauseAward != null || claimJob != null) return
    val country = countryIso()
    _state.update { it.copy(pauseAwardPending = true) }
    claimJob = scope.launch {
      finalBeat(country)
      val claim = claim()
      // A cancelled claim (a fresh visit superseded it) must not touch state —
      // its slot may already belong to the new visit's claim.
      if (!currentCoroutineContext().isActive) return@launch
      claimJob = null
      // No answer: the night's outcome stays unknown (pending).
      if (claim == null) return@launch
      _state.update { it.copy(pauseAwardPending = false, pauseAwardMissed = !claim.eligible) }
      if (claim.eligible) activitySink?.invoke(clock.now())
      val grant = claim.grant ?: return@launch
      _state.update { it.copy(pauseAward = grant) }
      awardSink?.invoke(grant)
    }
  }

  /** One last beat, bounded so a slow network can only hold the claim behind
   * it for [FINAL_BEAT_TIMEOUT]. Failures are swallowed. */
  private suspend fun finalBeat(country: String?) {
    withTimeoutOrNull(FINAL_BEAT_TIMEOUT.toMillis()) {
      try {
        remote.heartbeat(presenceId(), country)
      } catch (cancelled: CancellationException) {
        throw cancelled
      } catch (_: Exception) {
        null
      }
    }
  }

  /** Claims with a backoff, retrying only transport failures. Null when no
   * answer ever arrived. */
  private suspend fun claim(): PauseAwardClaim? {
    for (wait in claimRetryDelays) {
      if (wait > Duration.ZERO) delay(wait.toMillis())
      try {
        return remote.claimPauseAward()
      } catch (cancelled: CancellationException) {
        throw cancelled
      } catch (failure: Exception) {
        if (!isTransportFailure(failure)) return null
      }
    }
    return null
  }

  /**
   * Lets a claim already in flight land before the ending reads the books, so
   * the first reward screen opens on settled figures. Returns as it settles, or
   * after [timeout] — a claim that never arrives reconciles the stores behind
   * the ritual.
   */
  suspend fun settlePauseAward(timeout: Duration = SETTLE_TIMEOUT) {
    val job = claimJob ?: return
    withTimeoutOrNull(timeout.toMillis()) { job.join() }
  }

  // MARK: - Reflection (messages, intention & mood)

  /**
   * Posts a peace message tagged with the chosen intention (the server stores
   * it on the message *and* upserts tonight's reflection, so this one call is
   * the whole feedback phase). The first message of the night carries an award.
   */
  suspend fun post(message: String, intention: String?): PostedPeaceMessage {
    val posted = remote.postMessage(message, countryIso(), intention)
    _state.update { it.copy(postedMessage = posted.message) }
    posted.award?.let { award ->
      _state.update { it.copy(messageAward = award) }
      awardSink?.invoke(award)
    }
    return posted
  }

  suspend fun submit(intention: String?, mood: String?) {
    remote.submitReflection(intention, mood)
  }

  companion object {
    /**
     * How long before the meditation the card flips to its countdown — a
     * client presentation choice, mirrored by the dev time-travel route
     * (`COUNTDOWN_LEAD_MS` in deep-api/src/routes/pauseLive.ts).
     */
    val COUNTDOWN_LEAD: Duration = Duration.ofMinutes(15)

    val HEARTBEAT_INTERVAL: Duration = Duration.ofSeconds(10)
    val POLL_INTERVAL: Duration = Duration.ofSeconds(5)
    val FINAL_BEAT_TIMEOUT: Duration = Duration.ofSeconds(3)
    val SETTLE_TIMEOUT: Duration = Duration.ofSeconds(5)
    val NO_SCHEDULE_RETRY: Duration = Duration.ofSeconds(60)
    val DEFAULT_CLAIM_RETRY_DELAYS: List<Duration> =
      listOf(Duration.ZERO, Duration.ofSeconds(1), Duration.ofSeconds(2), Duration.ofSeconds(4))

    private val MIN_BOUNDARY_WAIT: Duration = Duration.ofMillis(50)
    private const val JOIN_BUFFER = 16
  }
}
