package io.appbeyond.freelance.deep.feature.deepsession.model

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.ZERO

/**
 * Drives one guided session: which breath phase we're in, which round, and whether
 * the practice is paused or complete.
 *
 * Pure clockwork — no UI, no audio — so the screen stays a projection of this
 * state and a preview can pin any moment of the session.
 *
 * Ported from Deep/Deep/Features/DeepSession/Models/BreathEngine.swift. The
 * structure is unchanged; two things are injected that iOS reaches for globally:
 *
 * - [scope] instead of an unstructured `Task {}`, so the engine's clock is owned
 *   by whoever created it and dies with them.
 * - [nowMillis] instead of `Date()`, which is what lets a test drive the whole
 *   session on virtual time. The iOS suite has to run against a real clock and
 *   says so in its own header: *"phases and timeouts here are kept short but
 *   generous — fast enough to run quickly, loose enough not to flake on a busy CI
 *   machine."* With a supplied clock, the Kotlin tests assert exact boundaries in
 *   microseconds and cannot flake.
 */
class BreathEngine(
  val session: DeepSession,
  private val scope: CoroutineScope,
  private val nowMillis: () -> Long = System::currentTimeMillis,
) {

  enum class Phase { Inhale, Exhale, Finished }

  data class State(
    val phase: Phase = Phase.Inhale,
    /** 1-based current round, capped at [DeepSession.cycles]. */
    val cycle: Int = 1,
    val isPaused: Boolean = false,
  )

  private val _state = MutableStateFlow(State())
  val state: StateFlow<State> = _state.asStateFlow()

  private var advanceJob: Job? = null
  private var phaseEndsAtMillis: Long? = null

  /** What was left of the current phase when it was paused. */
  private var pausedRemaining: Duration? = null

  /** Starts the clock. Safe to call once on first composition; later calls no-op. */
  fun begin() {
    val current = _state.value
    if (advanceJob != null || current.phase == Phase.Finished || current.isPaused) return
    scheduleAdvance(durationOf(current.phase))
  }

  fun togglePaused() {
    if (_state.value.phase == Phase.Finished) return
    if (_state.value.isPaused) resume() else pause()
  }

  /** Stops the clock without changing visible state; call on dismissal. */
  fun cancel() {
    advanceJob?.cancel()
    advanceJob = null
  }

  /**
   * Internal rather than only [togglePaused]'s half, so the screen can settle the
   * practice when the app leaves the foreground.
   */
  fun pause() {
    val current = _state.value
    if (current.phase == Phase.Finished || current.isPaused) return
    pausedRemaining = remainingInPhase
    cancel()
    _state.value = current.copy(isPaused = true)
  }

  private fun resume() {
    val remaining = pausedRemaining ?: durationOf(_state.value.phase)
    pausedRemaining = null
    _state.value = _state.value.copy(isPaused = false)
    scheduleAdvance(remaining)
  }

  /**
   * What is left of the current phase — live while the clock runs, frozen while
   * paused. Null before [begin] and once finished.
   */
  val remainingInPhase: Duration?
    get() = pausedRemaining
      ?: phaseEndsAtMillis?.let { end -> (end - nowMillis()).coerceAtLeast(0L).milliseconds }

  /** The full length of the phase we're currently in. */
  val currentPhaseDuration: Duration get() = durationOf(_state.value.phase)

  /**
   * Practice still ahead — what remains of this phase, the rest of this round, and
   * every round after it. Read live, like [remainingInPhase], so a caller re-reads
   * it whenever something else moves them.
   */
  val remainingInSession: Duration
    get() {
      val current = _state.value
      if (current.phase == Phase.Finished) return ZERO
      val inThisPhase = remainingInPhase ?: durationOf(current.phase)
      val restOfRound = if (current.phase == Phase.Inhale) session.exhale else ZERO
      val roundsAhead = (session.cycles - current.cycle).coerceAtLeast(0)
      return inThisPhase + restOfRound + session.cycleDuration * roundsAhead
    }

  private fun scheduleAdvance(after: Duration) {
    phaseEndsAtMillis = nowMillis() + after.inWholeMilliseconds
    advanceJob = scope.launch {
      delay(after)
      if (isActive) advance()
    }
  }

  private fun advance() {
    val current = _state.value
    when (current.phase) {
      Phase.Inhale -> {
        _state.value = current.copy(phase = Phase.Exhale)
        scheduleAdvance(session.exhale)
      }

      Phase.Exhale ->
        if (current.cycle >= session.cycles) {
          _state.value = current.copy(phase = Phase.Finished)
          phaseEndsAtMillis = null
          advanceJob = null
        } else {
          _state.value = current.copy(phase = Phase.Inhale, cycle = current.cycle + 1)
          scheduleAdvance(session.inhale)
        }

      Phase.Finished -> Unit
    }
  }

  private fun durationOf(phase: Phase): Duration = when (phase) {
    Phase.Inhale -> session.inhale
    Phase.Exhale -> session.exhale
    Phase.Finished -> ZERO
  }
}
