package io.appbeyond.freelance.deep.feature.deepsession.model

import io.appbeyond.freelance.deep.feature.deepsession.model.BreathEngine.Phase
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds
import kotlin.time.Duration.Companion.ZERO

/**
 * Ported from Deep/DeepTests/BreathEngineTests.swift.
 *
 * The Swift suite opens by apologising for its own clock: *"The engine runs on a
 * real Task.sleep clock, so phases and timeouts here are kept short but generous
 * — fast enough to run quickly, loose enough not to flake on a busy CI machine."*
 * It then polls with a `waitUntil(timeout:)` helper.
 *
 * Because [BreathEngine] takes its clock as a parameter, these run on virtual
 * time instead: the whole session completes in microseconds, every boundary is
 * asserted exactly rather than approximately, and there is nothing left to flake.
 * The `waitUntil` helper has no counterpart here.
 */
class BreathEngineTest {

  /** Two rounds of a 50ms inhale and a 50ms exhale. */
  private fun fixtureSession() = DeepSession(
    id = "test",
    title = "Test",
    tagline = "",
    inhale = 50.milliseconds,
    exhale = 50.milliseconds,
    cycles = 2,
  )

  /** The shipped 4s in / 6s out pattern, over six rounds. */
  private fun minuteSession() = DeepSession(
    id = "test",
    title = "Test",
    tagline = "",
    inhale = 4.seconds,
    exhale = 6.seconds,
    cycles = 6,
  )

  private fun TestScope.engineFor(session: DeepSession) =
    BreathEngine(session, backgroundScope) { testScheduler.currentTime }

  /** advanceTimeBy is exclusive of the target instant; runCurrent lands on it. */
  private fun TestScope.elapse(duration: Duration) {
    advanceTimeBy(duration)
    runCurrent()
  }

  @Test
  @DisplayName("begin starts in the inhale of cycle one")
  fun beginStartsInInhaleOfCycleOne() = runTest {
    val engine = engineFor(fixtureSession())
    engine.begin()

    assertEquals(Phase.Inhale, engine.state.value.phase)
    assertEquals(1, engine.state.value.cycle)
    engine.cancel()
  }

  @Test
  @DisplayName("advances through phases and cycles to finished")
  fun advancesThroughPhasesAndCyclesToFinished() = runTest {
    val engine = engineFor(fixtureSession())
    engine.begin()

    elapse(50.milliseconds)
    assertEquals(Phase.Exhale, engine.state.value.phase)
    assertEquals(1, engine.state.value.cycle)

    elapse(50.milliseconds)
    assertEquals(Phase.Inhale, engine.state.value.phase)
    assertEquals(2, engine.state.value.cycle)

    elapse(100.milliseconds)
    assertEquals(Phase.Finished, engine.state.value.phase)
    engine.cancel()
  }

  @Test
  @DisplayName("a phase holds right up to its boundary, and turns on it")
  fun phaseTurnsExactlyOnItsBoundary() = runTest {
    // The assertion the iOS suite cannot make: one millisecond before the
    // boundary the phase must not have moved, and on it, it must have.
    val engine = engineFor(fixtureSession())
    engine.begin()

    elapse(49.milliseconds)
    assertEquals(Phase.Inhale, engine.state.value.phase)

    elapse(1.milliseconds)
    assertEquals(Phase.Exhale, engine.state.value.phase)
    engine.cancel()
  }

  @Test
  @DisplayName("pausing stops advancement and freezes what is left of the phase")
  fun togglePausedStopsAdvancement() = runTest {
    val engine = engineFor(fixtureSession())
    engine.begin()

    elapse(50.milliseconds)
    engine.togglePaused()
    assertTrue(engine.state.value.isPaused)

    val phaseAtPause = engine.state.value.phase
    val remainingAtPause = engine.remainingInPhase
    assertNotNull(remainingAtPause)
    assertTrue(remainingAtPause <= engine.currentPhaseDuration)

    // Well past the phase's length. A paused engine must not advance.
    elapse(200.milliseconds)
    assertEquals(phaseAtPause, engine.state.value.phase)
    // And the frozen figure must not have drained while the clock ran.
    assertEquals(remainingAtPause, engine.remainingInPhase)

    engine.cancel()
  }

  @Test
  @DisplayName("resuming continues mid-phase rather than restarting it")
  fun resumingContinuesMidPhase() = runTest {
    val engine = engineFor(fixtureSession())
    engine.begin()

    elapse(30.milliseconds)
    engine.togglePaused()
    elapse(500.milliseconds) // time passes while paused; it must not count
    engine.togglePaused()

    // 20ms of the inhale was left. 19 must not be enough, 20 must be.
    elapse(19.milliseconds)
    assertEquals(Phase.Inhale, engine.state.value.phase)
    elapse(1.milliseconds)
    assertEquals(Phase.Exhale, engine.state.value.phase)

    engine.cancel()
  }

  @Test
  @DisplayName("cancel stops the clock")
  fun cancelStopsTheClock() = runTest {
    val engine = engineFor(fixtureSession())
    engine.begin()
    engine.cancel()

    val phaseAfterCancel = engine.state.value.phase
    elapse(200.milliseconds)
    assertEquals(phaseAfterCancel, engine.state.value.phase)
  }

  @Test
  @DisplayName("begin twice does not double-advance")
  fun beginTwiceDoesNotDoubleAdvance() = runTest {
    val engine = engineFor(fixtureSession())
    engine.begin()
    engine.begin()

    elapse(100.milliseconds)
    assertEquals(Phase.Inhale, engine.state.value.phase)
    assertEquals(2, engine.state.value.cycle)
    engine.cancel()
  }

  @Test
  @DisplayName("remaining in session starts at the whole length")
  fun remainingInSessionStartsAtTheWholeLength() = runTest {
    val session = minuteSession()
    val engine = engineFor(session)
    assertEquals(session.duration, engine.remainingInSession)
  }

  @Test
  @DisplayName("remaining in session falls as rounds pass")
  fun remainingInSessionFallsAsRoundsPass() = runTest {
    val engine = engineFor(fixtureSession())
    val atStart = engine.remainingInSession
    engine.begin()

    elapse(100.milliseconds)
    assertEquals(2, engine.state.value.cycle)
    assertTrue(engine.remainingInSession < atStart)
    engine.cancel()
  }

  @Test
  @DisplayName("remaining in session is nothing once finished")
  fun remainingInSessionIsNothingOnceFinished() = runTest {
    val engine = engineFor(fixtureSession())
    engine.begin()

    elapse(200.milliseconds)
    assertEquals(Phase.Finished, engine.state.value.phase)
    assertEquals(ZERO, engine.remainingInSession)
    engine.cancel()
  }
}
