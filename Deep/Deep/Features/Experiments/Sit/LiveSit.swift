#if EXPERIMENTS
import Foundation

/// How long a sit lasts. Every art spreads itself over the whole length.
enum SitLength: Int, CaseIterable, Identifiable {
  case three = 3
  case five = 5
  case ten = 10

  var id: Int { rawValue }
  var seconds: Double { Double(rawValue) * 60 }
  var label: String { "\(rawValue) min" }
}

/// Why a sit is paused.
enum SitPause: Equatable {
  /// The Bluetooth link dropped.
  case reconnecting
  /// The headband is off, or no sensor touches skin.
  case noSignal
}

/// One sit as it happens: frames accumulate as the headband sends them, so the art
/// only ever knows the past. The clock is the data (ten frames a second), so the sit
/// pauses by itself whenever frames stop coming.
@MainActor
@Observable
final class LiveSit {
  static let frameRate = 10.0

  let length: Double
  /// Observed, for the stage's captions and buttons.
  private(set) var pause: SitPause?
  private(set) var isFinished = false
  /// Whole seconds, so observers redraw once a second, not ten times.
  private(set) var wholeSeconds = 0

  /// Every frame so far, `time` restamped to session seconds. Read inside a
  /// TimelineView; not observed.
  @ObservationIgnored private(set) var frames: [EEGFrame] = []
  @ObservationIgnored private(set) var events: [EEGEvent] = []
  /// Artifacts with the wall time they arrived, for effects that answer at once
  /// (Aurora's shimmer, a lantern's flicker).
  @ObservationIgnored private(set) var recentArtifacts: [(kind: EEGArtifactKind, wall: Double)] = []
  @ObservationIgnored private var sums: [Sums] = [Sums()]
  @ObservationIgnored private var lastFrameWall: Double?
  @ObservationIgnored private var theta = 0.2

  /// Running totals, so any window's mean is one subtraction.
  private struct Sums {
    var relative = BandPowers.zero
    var calm = 0.0
    var stillness = 0.0
  }

  init(length: Double) {
    self.length = length
  }

  /// Session seconds of data so far.
  var elapsed: Double { Double(frames.count) / Self.frameRate }
  var progress: Double { min(elapsed / length, 1) }
  var remaining: Double { max(length - elapsed, 0) }

  // MARK: Feeding

  func absorb(_ tick: HeadbandTick, wall: Double = Date.timeIntervalSinceReferenceDate) {
    guard !isFinished else { return }
    for kind in tick.artifacts {
      recentArtifacts.append((kind, wall))
      events.append(EEGEvent(id: events.count, kind: kind, time: elapsed))
    }
    recentArtifacts.removeAll { wall - $0.wall > 8 }
    guard var frame = tick.frame else { return }

    frame.time = elapsed
    theta += (frame.relative.theta - theta) * (1 - exp(-1 / (Self.frameRate * 4)))
    frame.phase = MeditationPhase.classify(elapsed: elapsed, length: length, calm: frame.calm, theta: theta)
    frames.append(frame)
    // Frames handed over within a few milliseconds of each other are one batch.
    if wall - (lastFrameWall ?? -1) > 0.02 {
      if batchFrames > 0 { framePace = Double(batchFrames) / Self.frameRate }
      batchFrames = 0
    }
    batchFrames += 1
    lastFrameWall = wall

    var next = sums[sums.count - 1]
    next.relative = next.relative + frame.relative
    next.calm += frame.calm
    next.stillness += frame.stillness
    sums.append(next)

    if Int(elapsed) != wholeSeconds { wholeSeconds = Int(elapsed) }
    if elapsed >= length {
      isFinished = true
      finishedWall = wall
    }
  }

  func setPause(_ pause: SitPause?) {
    if self.pause != pause { self.pause = pause }
  }

  /// Ends the sit early, keeping what was painted.
  func finish() {
    guard !isFinished else { return }
    isFinished = true
    finishedWall = Date.timeIntervalSinceReferenceDate
    pause = nil
  }

  // MARK: Reading

  /// The newest frame, blended toward the one before over a tick so a 60 fps reader
  /// never sees a step. Nil before the first frame.
  func frame(at date: Date) -> EEGFrame? {
    guard let last = frames.last else { return nil }
    guard frames.count >= 2, let lastFrameWall else { return last }
    let since = date.timeIntervalSinceReferenceDate - lastFrameWall
    let amount = min(max(since * Self.frameRate, 0), 1)
    return frames[frames.count - 2].mixed(with: last, amount)
  }

  /// Session seconds at a wall moment, smooth between frames (frames come in batches
  /// when a demo plays fast). Holds still while the sit is paused. Once the sit is
  /// finished it runs on in real time past the end, so motion that was under way (a
  /// lantern still rising) can come to rest.
  func sessionTime(at date: Date) -> Double {
    if let finishedWall {
      return elapsed + max(date.timeIntervalSinceReferenceDate - finishedWall, 0) * Self.settleSpeed
    }
    guard let lastFrameWall, pause == nil else { return elapsed }
    let since = max(date.timeIntervalSinceReferenceDate - lastFrameWall, 0)
    // Frames arrive in batches every tenth of a wall second.
    let rate = framePace / 0.1
    return max(elapsed - framePace + min(since * rate, framePace * 1.5), 0)
  }

  /// Session seconds one batch of frames covers (0.1 for a real headband, 0.4 for a
  /// 4× demo), for `sessionTime(at:)`.
  @ObservationIgnored private var framePace = 0.1
  @ObservationIgnored private var batchFrames = 0
  /// How fast the clock runs once the sit has ended, so the last motion settles in
  /// seconds rather than half a minute.
  static let settleSpeed = 3.0
  /// Wall time the sit ended, for `sessionTime(at:)`.
  @ObservationIgnored private var finishedWall: Double?

  /// Mean band powers, calm and stillness over session seconds `from..<to` (clamped to
  /// what has happened). Nil for an empty window.
  func mean(from: Double, to: Double) -> (powers: BandPowers, calm: Double, stillness: Double)? {
    let lower = min(max(Int(from * Self.frameRate), 0), frames.count)
    let upper = min(max(Int(to * Self.frameRate), lower), frames.count)
    guard upper > lower else { return nil }
    let count = Double(upper - lower)
    let a = sums[lower]
    let b = sums[upper]
    var powers = BandPowers.zero
    for band in EEGBand.allCases { powers[band] = (b.relative[band] - a.relative[band]) / count }
    return (powers, (b.calm - a.calm) / count, (b.stillness - a.stillness) / count)
  }

  /// Artifacts within session seconds `from..<to`.
  func events(from: Double, to: Double) -> [EEGEvent] {
    events.filter { $0.time >= from && $0.time < to }
  }

  /// A finished sit built from a recording in one go, for previews and tests.
  static func replaying(_ recording: EEGSessionRecording, length: Double, upTo seconds: Double? = nil) -> LiveSit {
    let sit = LiveSit(length: length)
    let count = Int(min(seconds ?? length, length) * frameRate)
    for index in 0..<count {
      let frame = recording.frames[index % recording.frames.count]
      var artifacts: [EEGArtifactKind] = []
      if frame.blink { artifacts.append(.blink) }
      if frame.jawClench { artifacts.append(.jawClench) }
      sit.absorb(HeadbandTick(frame: frame, artifacts: artifacts, fit: SensorFit(channels: frame.fit, headbandOn: true)))
    }
    return sit
  }
}
#endif
