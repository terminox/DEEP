import Testing
import Foundation
@testable import Deep

/// Timing tests for `BreathEngine`. The engine runs on a real `Task.sleep`
/// clock, so phases and timeouts here are kept short but generous — fast
/// enough to run quickly, loose enough not to flake on a busy CI machine.
@MainActor
struct BreathEngineTests {
  /// Two rounds of a 50ms inhale / 50ms exhale — a full session in ~200ms.
  private static func fixtureSession() -> DeepSession {
    DeepSession(title: "Test", tagline: "", inhale: 0.05, exhale: 0.05, cycles: 2)
  }

  @Test
  func beginStartsInInhaleOfCycleOne() async {
    let engine = BreathEngine(session: Self.fixtureSession())
    engine.begin()
    #expect(engine.phase == .inhale)
    #expect(engine.cycle == 1)
    engine.cancel()
  }

  @Test
  func advancesThroughPhasesAndCyclesToFinished() async {
    let engine = BreathEngine(session: Self.fixtureSession())
    engine.begin()

    await waitUntil(timeout: 2) { engine.phase == .exhale }
    #expect(engine.phase == .exhale)
    #expect(engine.cycle == 1)

    await waitUntil(timeout: 2) { engine.cycle == 2 }
    #expect(engine.cycle == 2)
    #expect(engine.phase == .inhale)

    await waitUntil(timeout: 2) { engine.phase == .finished }
    #expect(engine.phase == .finished)
    engine.cancel()
  }

  @Test
  func togglePausedStopsAdvancement() async {
    let engine = BreathEngine(session: Self.fixtureSession())
    engine.begin()

    await waitUntil(timeout: 2) { engine.phase == .exhale }
    engine.togglePaused()
    #expect(engine.isPaused)

    let phaseAtPause = engine.phase
    // Wait longer than the phase duration; a paused engine must not advance.
    try? await Task.sleep(for: .milliseconds(200))
    #expect(engine.phase == phaseAtPause)
    if let remaining = engine.remainingInPhase {
      #expect(remaining <= engine.currentPhaseDuration)
    }

    engine.cancel()
  }

  @Test
  func cancelStopsTheClock() async {
    let engine = BreathEngine(session: Self.fixtureSession())
    engine.begin()
    engine.cancel()

    let phaseAfterCancel = engine.phase
    try? await Task.sleep(for: .milliseconds(200))
    #expect(engine.phase == phaseAfterCancel)
  }

  @Test
  func beginTwiceDoesNotDoubleAdvance() async {
    let engine = BreathEngine(session: Self.fixtureSession())
    engine.begin()
    engine.begin()

    await waitUntil(timeout: 2) { engine.cycle == 2 && engine.phase == .inhale }
    #expect(engine.cycle == 2)
    #expect(engine.phase == .inhale)
    engine.cancel()
  }

  /// Polls `condition` on a short interval until it's true or `timeout`
  /// elapses (in seconds), so timing assertions don't race the real clock.
  private func waitUntil(
    timeout: TimeInterval,
    condition: @MainActor () -> Bool
  ) async {
    let deadline = Date(timeIntervalSinceNow: timeout)
    while !condition(), Date() < deadline {
      try? await Task.sleep(for: .milliseconds(10))
    }
  }
}
