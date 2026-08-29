import Foundation
import Observation

/// Drives one guided session: which breath phase we're in, which round, and
/// whether the practice is paused or complete. Pure clockwork — no UI, no
/// audio — so the screen stays a projection of this state and previews can
/// pin any moment of the session.
@Observable @MainActor
final class BreathEngine {
  enum Phase {
    case inhale
    case exhale
    case finished
  }

  let session: DeepSession
  private(set) var phase: Phase = .inhale
  /// 1-based current round, capped at `session.cycles`.
  private(set) var cycle = 1
  private(set) var isPaused = false

  private var advanceTask: Task<Void, Never>?
  private var phaseEnds: Date?
  /// Seconds left in the current phase, captured when pausing.
  private var pausedRemaining: TimeInterval?

  init(session: DeepSession) {
    self.session = session
  }

  /// Starts the clock. Safe to call once from `onAppear`; later calls no-op.
  func begin() {
    guard advanceTask == nil, phase != .finished, !isPaused else { return }
    scheduleAdvance(after: duration(of: phase))
  }

  func togglePaused() {
    guard phase != .finished else { return }
    isPaused ? resume() : pause()
  }

  /// Stops the clock without changing visible state; call on dismiss.
  func cancel() {
    advanceTask?.cancel()
    advanceTask = nil
  }

  /// Seconds left in the current phase — live while the clock runs, frozen
  /// while paused. `nil` before `begin()` and once finished.
  var remainingInPhase: TimeInterval? {
    pausedRemaining ?? phaseEnds.map { max(0, $0.timeIntervalSinceNow) }
  }

  /// The full length of the phase we're currently in.
  var currentPhaseDuration: TimeInterval { duration(of: phase) }

  /// Seconds of practice still ahead — what remains of this phase, the rest of
  /// this round, and every round after it. Read live, like `remainingInPhase`,
  /// so a caller re-reads it whenever something else moves them.
  var remainingInSession: TimeInterval {
    guard phase != .finished else { return 0 }
    let inThisPhase = remainingInPhase ?? duration(of: phase)
    let restOfRound = phase == .inhale ? session.exhale : 0
    let roundsAhead = TimeInterval(max(0, session.cycles - cycle))
    return inThisPhase + restOfRound + roundsAhead * session.cycleDuration
  }

  /// Internal (not just `togglePaused`'s half) so the coordinator can settle
  /// the practice when the app leaves the foreground.
  func pause() {
    guard phase != .finished, !isPaused else { return }
    isPaused = true
    pausedRemaining = phaseEnds.map { max(0, $0.timeIntervalSinceNow) }
    cancel()
  }

  private func resume() {
    isPaused = false
    scheduleAdvance(after: pausedRemaining ?? duration(of: phase))
    pausedRemaining = nil
  }

  private func scheduleAdvance(after seconds: TimeInterval) {
    phaseEnds = Date(timeIntervalSinceNow: seconds)
    advanceTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(seconds))
      guard !Task.isCancelled else { return }
      self?.advance()
    }
  }

  private func advance() {
    switch phase {
    case .inhale:
      phase = .exhale
      scheduleAdvance(after: session.exhale)
    case .exhale:
      if cycle >= session.cycles {
        phase = .finished
        advanceTask = nil
      } else {
        cycle += 1
        phase = .inhale
        scheduleAdvance(after: session.inhale)
      }
    case .finished:
      break
    }
  }

  private func duration(of phase: Phase) -> TimeInterval {
    switch phase {
    case .inhale: session.inhale
    case .exhale: session.exhale
    case .finished: 0
    }
  }
}

extension BreathEngine {
  /// A stopped engine pinned to one moment of the session, for previews.
  /// `session` defaults to the balancing breath (resolved in the body — a
  /// default argument can't touch the MainActor-isolated library).
  static func still(
    session: DeepSession? = nil,
    phase: Phase,
    cycle: Int = 1,
    isPaused: Bool = false
  ) -> BreathEngine {
    let engine = BreathEngine(session: session ?? DeepSessionLibrary.balancingBreath)
    engine.phase = phase
    engine.cycle = cycle
    engine.isPaused = isPaused
    return engine
  }
}
