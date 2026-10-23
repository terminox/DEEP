package io.appbeyond.freelance.deep.shared.refresh

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Ported from Deep/Deep/Shared/Components/RefreshCue.swift's `RefreshMonitor`
 * — the pure gesture-gating and timing rules behind the app's hero-led pull
 * -to-refresh, independent of the scroll geometry and coroutines that drive it
 * on Android.
 */
class RefreshCueTest {
  private val idle = RefreshCueState()

  // MARK: - dead zone

  @Test
  @DisplayName("pull progress is zero within the appearance dead zone")
  fun pullProgressIsZeroWithinDeadZone() {
    val state = RefreshCueMachine.pull(idle, distance = 10f, dragging = true, nowMillis = 0)
    assertEquals(0f, RefreshCueMachine.pullProgress(state))
  }

  @Test
  @DisplayName("the cue stays hidden until the pull clears the dead zone")
  fun cueStaysHiddenWithinDeadZone() {
    val atZone = RefreshCueMachine.pull(idle, distance = RefreshCueMachine.APPEARANCE, dragging = true, nowMillis = 0)
    assertFalse(RefreshCueMachine.isVisible(atZone))

    val pastZone = RefreshCueMachine.pull(
      idle,
      distance = RefreshCueMachine.APPEARANCE + 1f,
      dragging = true,
      nowMillis = 0,
    )
    assertTrue(RefreshCueMachine.isVisible(pastZone))
  }

  @Test
  @DisplayName("pull progress reaches one exactly at the threshold")
  fun pullProgressReachesOneAtThreshold() {
    // Stop just short of the threshold so this doesn't itself trigger a refresh.
    val state = RefreshCueState(pull = RefreshCueMachine.THRESHOLD, isDragging = false)
    assertEquals(1f, RefreshCueMachine.pullProgress(state))
  }

  // MARK: - threshold fires only while dragging

  @Test
  @DisplayName("crossing the threshold while dragging fires the refresh")
  fun crossingThresholdWhileDraggingFires() {
    val state = RefreshCueMachine.pull(
      idle,
      distance = RefreshCueMachine.THRESHOLD,
      dragging = true,
      nowMillis = 1_000,
    )
    assertEquals(RefreshCuePhase.Refreshing, state.phase)
    assertEquals(1_000L, state.refreshStartedAtMillis)
  }

  @Test
  @DisplayName("crossing the threshold with the finger already up never fires")
  fun crossingThresholdWithFingerUpNeverFires() {
    val state = RefreshCueMachine.pull(
      idle,
      distance = RefreshCueMachine.THRESHOLD,
      dragging = false,
      nowMillis = 0,
    )
    assertEquals(RefreshCuePhase.Idle, state.phase)
  }

  // MARK: - fling doesn't fire

  @Test
  @DisplayName("a fling that decelerates through the threshold after release never fires")
  fun flingThroughThresholdAfterReleaseNeverFires() {
    // The finger lifts while the pull is still short of the threshold...
    var state = RefreshCueMachine.pull(idle, distance = 30f, dragging = true, nowMillis = 0)
    state = RefreshCueMachine.pull(state, distance = 30f, dragging = false, nowMillis = 0)
    // ...then the fling's own momentum carries the overscroll on past it.
    state = RefreshCueMachine.pull(state, distance = RefreshCueMachine.THRESHOLD + 20f, dragging = false, nowMillis = 100)

    assertEquals(RefreshCuePhase.Idle, state.phase)
  }

  // MARK: - re-arm below 10

  @Test
  @DisplayName("a finishing refresh stays up while the pull sits at or above the reset point")
  fun finishingStaysUpAtOrAboveReset() {
    var state = RefreshCueMachine.pull(idle, distance = RefreshCueMachine.THRESHOLD, dragging = true, nowMillis = 0)
    state = RefreshCueMachine.refreshFinished(state, nowMillis = RefreshCueMachine.MIN_SPINNER_MILLIS)
    assertEquals(RefreshCuePhase.Finishing, state.phase)

    val stillHeld = RefreshCueMachine.pull(state, distance = RefreshCueMachine.RESET, dragging = true, nowMillis = RefreshCueMachine.MIN_SPINNER_MILLIS)
    assertEquals(RefreshCuePhase.Finishing, stillHeld.phase)
  }

  @Test
  @DisplayName("a finishing refresh re-arms once the pull drops below the reset point")
  fun finishingReArmsBelowReset() {
    var state = RefreshCueMachine.pull(idle, distance = RefreshCueMachine.THRESHOLD, dragging = true, nowMillis = 0)
    state = RefreshCueMachine.refreshFinished(state, nowMillis = RefreshCueMachine.MIN_SPINNER_MILLIS)
    assertEquals(RefreshCuePhase.Finishing, state.phase)

    val released = RefreshCueMachine.pull(
      state,
      distance = RefreshCueMachine.RESET - 0.1f,
      dragging = false,
      nowMillis = RefreshCueMachine.MIN_SPINNER_MILLIS,
    )
    assertEquals(RefreshCuePhase.Idle, released.phase)
  }

  // MARK: - minimum 600ms spinner hold

  @Test
  @DisplayName("the spinner holds even when the action finishes before the floor")
  fun spinnerHoldsBeforeFloorElapses() {
    var state = RefreshCueMachine.pull(idle, distance = RefreshCueMachine.THRESHOLD, dragging = true, nowMillis = 0)
    state = RefreshCueMachine.refreshFinished(state, nowMillis = RefreshCueMachine.MIN_SPINNER_MILLIS - 1)
    assertEquals(RefreshCuePhase.Refreshing, state.phase)
  }

  @Test
  @DisplayName("the spinner releases once the floor has actually elapsed")
  fun spinnerReleasesAfterFloorElapses() {
    var state = RefreshCueMachine.pull(idle, distance = RefreshCueMachine.THRESHOLD, dragging = true, nowMillis = 0)
    state = RefreshCueMachine.refreshFinished(state, nowMillis = RefreshCueMachine.MIN_SPINNER_MILLIS)
    assertEquals(RefreshCuePhase.Finishing, state.phase)
  }

  @Test
  @DisplayName("begin refresh is ignored while a refresh is already in flight")
  fun beginRefreshIgnoredWhileInFlight() {
    val refreshing = RefreshCueMachine.pull(idle, distance = RefreshCueMachine.THRESHOLD, dragging = true, nowMillis = 0)
    val stillRefreshing = RefreshCueMachine.beginRefresh(refreshing, nowMillis = 500)
    assertEquals(0L, stillRefreshing.refreshStartedAtMillis)
  }
}
