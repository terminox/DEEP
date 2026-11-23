#if EXPERIMENTS
import Foundation

/// DEEP's calm index. LibMuse reports no calm or meditation score, so this is ours:
/// frontal alpha against beta, α / (α + β) over AF7 and AF8, smoothed over ~4 s and
/// put on a soft saturating curve, so a very settled sitter still has headroom.
///
/// Every source goes through here (the simulated sit and a real headband alike), so a
/// value the art was tuned on means the same thing whichever one is playing.
nonisolated struct CalmIndex: Sendable {
  /// Seconds for the ratio to settle toward a new reading.
  static let smoothing = 4.0

  private(set) var ratio: Double
  private(set) var value: Double

  init(ratio: Double = 0.4) {
    self.ratio = ratio
    value = Self.map(ratio)
  }

  /// Folds in one reading taken `dt` seconds after the previous one.
  mutating func update(frontalAlpha: Double, beta: Double, dt: Double) -> Double {
    let sum = frontalAlpha + beta
    guard sum > 0, sum.isFinite else { return value }
    ratio += (frontalAlpha / sum - ratio) * (1 - exp(-dt / Self.smoothing))
    value = Self.map(ratio)
    return value
  }

  /// 0 at a ratio of 0.3 or below, rising toward (never reaching) 1.
  static func map(_ ratio: Double) -> Double {
    1 - exp(-1.7 * max(ratio - 0.3, 0) / 0.5)
  }
}

extension MeditationPhase {
  /// Where a sitter is, read from the data and how far through the sit they are.
  /// The simulated sit's rule, stretched to any length.
  nonisolated static func classify(elapsed: Double, length: Double, calm: Double, theta: Double) -> MeditationPhase {
    let progress = elapsed / max(length, 1)
    if progress < 0.125 { return .settling }
    if progress > 0.91 { return .returning }
    if calm < 0.3 { return .wandering }
    if calm > 0.62, theta > 0.2 { return .deep }
    return .drifting
  }
}
#endif
