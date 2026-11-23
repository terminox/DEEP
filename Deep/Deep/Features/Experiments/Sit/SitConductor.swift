#if EXPERIMENTS
import Foundation

/// Feeds a headband's ticks into a `LiveSit`, and pauses the sit when the signal goes:
/// the link drops ("Reconnecting…"), or the headband comes off. A live demo is the same
/// thing with a simulated headband, a full 10-minute sit and `loops`: when the sit ends
/// the finished art rests for a moment, then a new sit begins.
@MainActor
@Observable
final class SitConductor {
  /// Seconds without a usable frame before the sit says so.
  static let silenceBeforePause = 1.5
  /// How long a demo rests on its finished art before starting again.
  static let demoRest = 12.0

  private(set) var sit: LiveSit
  let headband: any MuseConnecting
  let loops: Bool

  @ObservationIgnored private var listening: Task<Void, Never>?
  @ObservationIgnored private var watchdog: Task<Void, Never>?
  @ObservationIgnored private var lastFrameAt = Date()
  @ObservationIgnored private var finishedAt: Date?

  init(headband: any MuseConnecting, length: Double, loops: Bool = false) {
    self.headband = headband
    self.loops = loops
    sit = LiveSit(length: length)
  }

  func start() {
    guard listening == nil else { return }
    lastFrameAt = Date()
    listening = Task { [weak self, headband] in
      for await tick in headband.ticks() {
        guard let self, !Task.isCancelled else { return }
        self.handle(tick)
      }
    }
    watchdog = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(500))
        self?.check()
      }
    }
  }

  func stop() {
    listening?.cancel()
    watchdog?.cancel()
    listening = nil
    watchdog = nil
  }

  /// Ends the sit now; the art keeps what was painted.
  func finish() {
    sit.finish()
    finishedAt = Date()
  }

  private func handle(_ tick: HeadbandTick) {
    guard !sit.isFinished else { return }
    if tick.frame != nil {
      lastFrameAt = Date()
      sit.setPause(nil)
    }
    sit.absorb(tick)
    if sit.isFinished { finishedAt = Date() }
  }

  private func check() {
    if sit.isFinished {
      if loops, let finishedAt, Date().timeIntervalSince(finishedAt) > Self.demoRest {
        self.finishedAt = nil
        sit = LiveSit(length: sit.length)
        lastFrameAt = Date()
      }
      return
    }
    guard Date().timeIntervalSince(lastFrameAt) > Self.silenceBeforePause else { return }
    if case .reconnecting = headband.link {
      sit.setPause(.reconnecting)
    } else if headband.link.isConnected {
      sit.setPause(.noSignal)
    } else {
      sit.setPause(.reconnecting)
    }
  }
}
#endif
