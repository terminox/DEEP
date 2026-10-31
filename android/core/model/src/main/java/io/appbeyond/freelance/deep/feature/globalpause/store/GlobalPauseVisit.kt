package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.feature.globalpause.model.GlobalPauseRewardSnapshot
import io.appbeyond.freelance.deep.feature.rewards.model.RewardReceipt
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import java.time.Duration

/**
 * One visit to the live Global Pause, from the moment the session opens to the
 * last reward beat: the meditation, which cannot be paused, then the
 * reflection, then the ritual.
 *
 * The logic half of iOS's `GlobalPauseSessionController` (and the ending's
 * `GlobalPauseCompletionView`), lifted out of the screen so it outlives one —
 * a screen that is stopped (the phone locked mid-sit) still reaches the
 * reflection on time, and its claim still goes out. The screens only render
 * [phase] and send intents.
 *
 * - [begin] enters presence and joins the shared stream at the synced offset.
 *   A latecomer past the end goes straight to the reflection — the stream is
 *   over.
 * - Three idempotent triggers end the meditation: the audio clock (primary),
 *   the live window closing (covers a realign zeroing the audio clock near the
 *   end), and a wall-clock fallback (covers a missing or failed audio URL).
 * - Ending it freezes the books ([snapshot]) *before* the claim goes out, so
 *   the ritual can show a true before/after, then claims tonight's attendance.
 *   Presence is released a beat later ([HANDBACK_DELAY], iOS's crossfade), so
 *   the claim's closing heartbeat reaches the server first.
 * - [continueToRewards] waits for the claim to settle, then composes the
 *   receipt ([receipt]) from what the stores hold by then.
 * - [leave] is the only other way out, and ends presence at once.
 *
 * @param snapshot the books as they stand right now — garden, hearts, whether
 *   today's rhythm is already witnessed.
 * @param receipt folds the night's settled grants onto the frozen books.
 * @param hydrate lets the practice journal take its first pull (bounded), run
 *   alongside settling the claim so the ritual shows the account's real
 *   rhythm without waiting for one and then the other.
 */
class GlobalPauseVisit(
  private val session: GlobalPauseSession,
  private val audio: GlobalPauseAudioPlaying,
  private val scope: CoroutineScope,
  private val snapshot: suspend () -> GlobalPauseRewardSnapshot,
  private val receipt: suspend (before: GlobalPauseRewardSnapshot) -> RewardReceipt,
  private val hydrate: suspend () -> Unit = {},
) {

  sealed interface Phase {
    /** Not begun yet — the screen is arriving. */
    data object Arriving : Phase

    /** The live meditation, [duration] long. */
    data class Meditating(val duration: Duration) : Phase

    /** The thank-you and the peace-message composer. */
    data object Reflecting : Phase

    /** The reward ritual, playing [receipt]. */
    data class Rewarding(val receipt: RewardReceipt) : Phase

    /** Over — the presenter dismisses. */
    data object Finished : Phase
  }

  private val _phase = MutableStateFlow<Phase>(Phase.Arriving)
  val phase: StateFlow<Phase> = _phase.asStateFlow()

  /** True while the ending settles tonight's award before the ritual. */
  private val _isPreparing = MutableStateFlow(false)
  val isPreparing: StateFlow<Boolean> = _isPreparing.asStateFlow()

  private var before: Deferred<GlobalPauseRewardSnapshot>? = null
  private var completed = false
  private var tornDown = false
  private val watchers = mutableListOf<Job>()

  /** One-shot: enters presence and joins the meditation at the shared offset. */
  fun begin() {
    if (_phase.value != Phase.Arriving || tornDown) return
    session.enterSession()

    val duration = session.meditationDuration.takeIf { it > Duration.ZERO } ?: FALLBACK_DURATION
    val offset = session.meditationElapsed
    if (offset >= duration) {
      endMeditation()
      return
    }
    _phase.value = Phase.Meditating(duration)

    // Recovery (interruption, stall) re-seeks to the live edge.
    audio.meditationOffsetProvider = { session.meditationElapsed }
    session.state.value.schedule?.meditationAudioUrl?.let { url ->
      audio.playMeditation(url, offset, duration)
    }

    watchers += scope.launch {
      audio.meditationElapsed.first { it >= duration.minus(END_TOLERANCE) }
      endMeditation()
    }
    watchers += scope.launch {
      session.state.map { it.isMeditationLive }.distinctUntilChanged().first { !it }
      endMeditation()
    }
    watchers += scope.launch {
      delay(duration.minus(offset).plus(FALLBACK_SLACK).toMillis())
      endMeditation()
    }
  }

  private fun endMeditation() {
    if (completed || tornDown) return
    completed = true
    watchers.forEach { it.cancel() }
    watchers.clear()

    // The books as they stand right now, before the claim moves them — so the
    // claim goes out only once they're frozen.
    before = scope.async {
      snapshot().also { session.claimPauseAward() }
    }
    _phase.value = Phase.Reflecting

    // The meditation is over; presence goes once the claim's closing beat has
    // had its moment — iOS releases it after the reflection's 1.5s crossfade.
    // Books slow to freeze don't hold it: the leave then goes first, and the
    // claim follows it with no beat of its own (`leaveSession`).
    scope.launch {
      delay(HANDBACK_DELAY.toMillis())
      tearDown()
    }
  }

  /**
   * The reflection is done (a message posted, a word kept, or neither): let any
   * claim still in flight land — and the practice journal hydrate — then
   * compose the ritual.
   */
  suspend fun continueToRewards() {
    if (_phase.value != Phase.Reflecting || _isPreparing.value) return
    val pending = before ?: return
    _isPreparing.value = true
    val frozen = pending.await()
    coroutineScope {
      val hydrated = launch { hydrate() }
      session.settlePauseAward()
      hydrated.join()
    }
    val composed = receipt(frozen)
    _isPreparing.value = false
    if (_phase.value == Phase.Reflecting) _phase.value = Phase.Rewarding(composed)
  }

  /** The ritual closed. */
  fun finish() {
    tearDown()
    _phase.value = Phase.Finished
  }

  /**
   * Leaving early — the member confirmed it mid-meditation, or left the
   * reflection. Ends presence at once.
   */
  fun leave() {
    watchers.forEach { it.cancel() }
    watchers.clear()
    tearDown()
    _phase.value = Phase.Finished
  }

  /** Audio off, presence released. Idempotent. */
  private fun tearDown() {
    if (tornDown) return
    tornDown = true
    audio.stop()
    session.leaveSession()
  }

  companion object {
    /** Used when the schedule carries no meditation length. */
    val FALLBACK_DURATION: Duration = Duration.ofMinutes(10)

    /** The audio clock's last half-second counts as the end. */
    val END_TOLERANCE: Duration = Duration.ofMillis(500)

    /** How long past the expected end the wall-clock fallback waits. */
    val FALLBACK_SLACK: Duration = Duration.ofSeconds(2)

    /** The meditation → reflection crossfade, before presence is released. */
    val HANDBACK_DELAY: Duration = Duration.ofMillis(1_500)
  }
}
