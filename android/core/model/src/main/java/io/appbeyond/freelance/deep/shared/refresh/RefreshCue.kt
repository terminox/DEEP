package io.appbeyond.freelance.deep.shared.refresh

/**
 * Ported from Deep/Deep/Shared/Components/RefreshCue.swift's `RefreshMonitor`
 * and `RefreshCueHost`.
 *
 * iOS drives this from two independent scroll callbacks (a per-frame pull
 * distance, and a separate touch-phase callback) plus a `Task` that runs the
 * refresh action alongside a 600 ms floor (`async let beat`) so the spinner
 * never flashes for an instantly-resolving fetch. None of that async
 * machinery is pure, so it stays out of this module: a Compose modifier owns
 * the coroutine that calls the refresh action and holds the floor, and drives
 * this reducer with plain events — [RefreshCueMachine.pull] for every scroll
 * update, [RefreshCueMachine.beginRefresh] when the pull crosses the
 * threshold (or VoiceOver asks directly), and [RefreshCueMachine.refreshFinished]
 * once both the action and the 600 ms floor have elapsed.
 */
enum class RefreshCuePhase {
  Idle,
  Refreshing,
  Finishing,
}

/** Immutable snapshot of the pull-to-refresh cue. */
data class RefreshCueState(
  val phase: RefreshCuePhase = RefreshCuePhase.Idle,
  /** Overscroll distance, in points, the caller reports every scroll update. */
  val pull: Float = 0f,
  /** Whether a finger is still down — a fling that decelerates through the
   * threshold must never trigger a refresh. */
  val isDragging: Boolean = false,
  /** When the current refresh started, for measuring the 600 ms floor. */
  val refreshStartedAtMillis: Long = 0L,
)

/** The pure pull-to-refresh state machine — no scrolling, no coroutines. */
object RefreshCueMachine {
  /** Overscroll distance that fires the refresh. */
  const val THRESHOLD = 52f

  /** Dead zone before the cue materialises, so incidental bounce stays clean. */
  const val APPEARANCE = 14f

  /** The pull must return below this before another refresh can arm. */
  const val RESET = 10f

  /** Minimum time the spinner stays up once a refresh starts. */
  const val MIN_SPINNER_MILLIS = 600L

  /** Reports a scroll update: the current overscroll and whether a finger is
   * still down. Arms a refresh when the pull crosses [THRESHOLD] while
   * [dragging], and re-arms once a finished refresh's pull has dropped below
   * [RESET]. */
  fun pull(state: RefreshCueState, distance: Float, dragging: Boolean, nowMillis: Long): RefreshCueState {
    val next = state.copy(pull = distance, isDragging = dragging)
    return settle(trigger(next, nowMillis))
  }

  /** Starts a refresh directly, bypassing the gesture gates — the
   * VoiceOver/accessibility entry point iOS exposes via `beginRefresh`. */
  fun beginRefresh(state: RefreshCueState, nowMillis: Long): RefreshCueState =
    if (state.phase == RefreshCuePhase.Idle) start(state, nowMillis) else state

  /** The refresh action (and the [MIN_SPINNER_MILLIS] floor) have both
   * completed. Moves to [RefreshCuePhase.Finishing] only once that floor has
   * actually elapsed; called too early, this is a no-op — the caller is
   * expected to have awaited the floor itself, exactly as iOS's `async let
   * beat` does, and this check exists so a driver bug can't shortchange it. */
  fun refreshFinished(state: RefreshCueState, nowMillis: Long): RefreshCueState {
    if (state.phase != RefreshCuePhase.Refreshing) return state
    if (nowMillis - state.refreshStartedAtMillis < MIN_SPINNER_MILLIS) return state
    return settle(state.copy(phase = RefreshCuePhase.Finishing))
  }

  /** 0…1 ramp from the [APPEARANCE] dead zone to the [THRESHOLD] trigger —
   * drives the ring fill and the cue's fade-in while idle. */
  fun pullProgress(state: RefreshCueState): Float {
    val span = THRESHOLD - APPEARANCE
    return ((state.pull - APPEARANCE) / span).coerceIn(0f, 1f)
  }

  /** Whether the cue should be shown at all: while actively pulling past the
   * dead zone, and for the whole refreshing/finishing lifetime regardless of
   * where the finger ends up. */
  fun isVisible(state: RefreshCueState): Boolean =
    state.phase != RefreshCuePhase.Idle || (state.isDragging && state.pull > APPEARANCE)

  /** The indeterminate spinner replaces the progress ring for the whole
   * refreshing/finishing lifetime. */
  fun isSpinning(state: RefreshCueState): Boolean = state.phase != RefreshCuePhase.Idle

  /** The cue's opacity: tracks the pull while idle, fully opaque once armed. */
  fun opacity(state: RefreshCueState): Float =
    if (state.phase == RefreshCuePhase.Idle) pullProgress(state) else 1f

  /** The cue's scale: settles in from 0.8 while idle, full size once armed. */
  fun scale(state: RefreshCueState): Float =
    if (state.phase == RefreshCuePhase.Idle) 0.8f + 0.2f * pullProgress(state) else 1f

  private fun trigger(state: RefreshCueState, nowMillis: Long): RefreshCueState {
    if (state.phase != RefreshCuePhase.Idle || !state.isDragging || state.pull < THRESHOLD) return state
    return start(state, nowMillis)
  }

  private fun start(state: RefreshCueState, nowMillis: Long): RefreshCueState =
    state.copy(phase = RefreshCuePhase.Refreshing, refreshStartedAtMillis = nowMillis)

  /** `.finishing` doubles as the re-arm latch: the cue stays up under a still
   * -held finger, and re-arming requires the pull to actually return near
   * rest first — no instant double-trigger. */
  private fun settle(state: RefreshCueState): RefreshCueState {
    if (state.phase != RefreshCuePhase.Finishing || state.pull >= RESET) return state
    return state.copy(phase = RefreshCuePhase.Idle)
  }
}
