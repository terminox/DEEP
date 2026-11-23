#if EXPERIMENTS
import Foundation

/// Turns the packets a Muse 2 sends into the app's 10 Hz `EEGFrame`s.
///
/// Pure value logic with no LibMuse types, so it is unit-tested on the simulator.
/// `MuseLink` unpacks each packet into one `ingest…` call on its own queue and asks
/// for a tick every 100 ms. All times are seconds on one monotonic clock.
nonisolated struct MuseFrameBuilder: Sendable {
  /// Readings older than this count as gone.
  static let staleAfter = 1.0
  /// How long the headband must be off, or every sensor lifted, before frames stop.
  static let offAfter = 1.0
  static let lostAfter = 2.0

  // Latest band powers, [band][channel], TP9 · AF7 · AF8 · TP10.
  private var relative = Array(repeating: Array(repeating: Double.nan, count: 4), count: 5)
  private var absolute = Array(repeating: Array(repeating: Double.nan, count: 4), count: 5)
  private var lastBandAt: Double?
  private(set) var fit = SensorFit(channels: Array(repeating: .bad, count: 4), headbandOn: true)
  // Assume the headband is on until an artifact packet says otherwise.
  private var offSince: Double?
  private var noGoodChannelSince: Double?
  private var calm = CalmIndex()
  private var lastTickAt: Double?
  private var lastFrame: EEGFrame?
  private var pendingArtifacts: [EEGArtifactKind] = []
  private var blinkHeld = false
  private var clenchHeld = false
  private(set) var motion = MotionMeter()
  private(set) var heart = HeartbeatDetector()
  /// Packets seen, by kind, for diagnostics.
  private(set) var counts: [String: Int] = [:]

  init() {}

  // MARK: Packets

  /// One band-power packet: four channel values of one band. LibMuse sends NaN for a
  /// channel it can't read.
  mutating func ingestBand(_ band: EEGBand, isRelative: Bool, channels: [Double], at time: Double) {
    guard channels.count >= 4 else { return }
    if isRelative {
      relative[band.rawValue] = Array(channels.prefix(4))
      lastBandAt = time
    } else {
      absolute[band.rawValue] = Array(channels.prefix(4))
    }
    count(isRelative ? "relative" : "absolute")
  }

  /// Horseshoe fit per channel: 1 good, 2 mediocre, 4 poor.
  mutating func ingestFit(_ values: [Double], at time: Double) {
    guard values.count >= 4 else { return }
    fit.channels = values.prefix(4).map { value in
      value <= 1.5 ? .good : value <= 2.5 ? .ok : .bad
    }
    if fit.channels.contains(where: { $0 != .bad }) {
      noGoodChannelSince = nil
    } else if noGoodChannelSince == nil {
      noGoodChannelSince = time
    }
    count("fit")
  }

  mutating func ingestArtifact(headbandOn: Bool, blink: Bool, jawClench: Bool, at time: Double) {
    fit.headbandOn = headbandOn
    if headbandOn {
      offSince = nil
    } else if offSince == nil {
      offSince = time
    }
    // Report each artifact once, when it begins.
    if blink, !blinkHeld { pendingArtifacts.append(.blink) }
    if jawClench, !clenchHeld { pendingArtifacts.append(.jawClench) }
    blinkHeld = blink
    clenchHeld = jawClench
    count("artifacts")
  }

  /// One accelerometer sample, in g.
  mutating func ingestAccelerometer(x: Double, y: Double, z: Double, at time: Double) {
    motion.add(x: x, y: y, z: z, at: time)
    count("accelerometer")
  }

  /// One PPG sample from the infrared channel.
  mutating func ingestPPG(_ value: Double, at time: Double) {
    heart.add(value, at: time)
    count("ppg")
  }

  // MARK: Ticks

  /// The next 10 Hz tick. Nil frame while there is no usable EEG.
  mutating func makeTick(at time: Double) -> HeadbandTick {
    let dt = lastTickAt.map { min(max(time - $0, 0.01), 1) } ?? 0.1
    lastTickAt = time
    defer { pendingArtifacts.removeAll() }
    let artifacts = pendingArtifacts

    let off = offSince.map { time - $0 >= Self.offAfter } ?? false
    let lifted = noGoodChannelSince.map { time - $0 >= Self.lostAfter } ?? false
    let stale = lastBandAt.map { time - $0 >= Self.staleAfter } ?? true
    guard !off, !lifted, !stale, let frame = frame(dt: dt, artifacts: artifacts) else {
      return HeadbandTick(frame: nil, artifacts: [], fit: fit)
    }
    lastFrame = frame
    return HeadbandTick(frame: frame, artifacts: artifacts, fit: fit)
  }

  /// A channel counts when its fit is good or mediocre and its value is finite.
  private func usable(_ channel: Int) -> Bool {
    fit.channels[channel] != .bad && relative[EEGBand.alpha.rawValue][channel].isFinite
  }

  private mutating func frame(dt: Double, artifacts: [EEGArtifactKind]) -> EEGFrame? {
    let good = (0..<4).filter(usable)
    guard !good.isEmpty else { return nil }

    func average(_ table: [[Double]], _ band: EEGBand) -> Double {
      let values = good.map { table[band.rawValue][$0] }.filter(\.isFinite)
      return values.isEmpty ? .nan : values.reduce(0, +) / Double(values.count)
    }
    var powers = BandPowers.zero
    var logPowers = BandPowers.zero
    for band in EEGBand.allCases {
      powers[band] = max(average(relative, band), 0)
      logPowers[band] = average(absolute, band)
      if !logPowers[band].isFinite { logPowers[band] = 0 }
    }
    let total = EEGBand.allCases.reduce(0) { $0 + powers[$1] }
    guard total > 0 else { return nil }
    powers = powers / total

    let alphas = (0..<4).map { channel in
      usable(channel) ? relative[EEGBand.alpha.rawValue][channel] : powers.alpha
    }
    // Calm reads the forehead. With both frontal sensors lifted it holds.
    let frontal = [1, 2].filter(usable)
    if !frontal.isEmpty {
      let alpha = frontal.map { relative[EEGBand.alpha.rawValue][$0] }.reduce(0, +) / Double(frontal.count)
      let beta = frontal.map { relative[EEGBand.beta.rawValue][$0] }.reduce(0, +) / Double(frontal.count)
      _ = calm.update(frontalAlpha: alpha, beta: beta, dt: dt)
    }

    return EEGFrame(
      time: 0,
      relative: powers,
      absolute: logPowers,
      channelAlpha: alphas,
      fit: fit.channels,
      heartRate: heart.bpm ?? lastFrame?.heartRate ?? HeartbeatDetector.restingGuess,
      stillness: motion.stillness,
      calm: calm.value,
      phase: .drifting,
      blink: artifacts.contains(.blink),
      jawClench: artifacts.contains(.jawClench)
    )
  }

  private mutating func count(_ kind: String) {
    counts[kind, default: 0] += 1
  }
}

/// How still the head is, from the accelerometer.
nonisolated struct MotionMeter: Sendable {
  /// Motion (g, gravity removed) that still reads perfectly still, and fully restless.
  static let still = 0.004
  static let restless = 0.04

  private var gravity: (x: Double, y: Double, z: Double)?
  private var lastAt: Double?
  /// Smoothed movement away from gravity, in g.
  private(set) var motion = 0.0

  var stillness: Double { 1 - eegSmoothstep(Self.still, Self.restless, motion) }

  mutating func add(x: Double, y: Double, z: Double, at time: Double) {
    guard x.isFinite, y.isFinite, z.isFinite else { return }
    let dt = lastAt.map { min(max(time - $0, 0), 0.5) } ?? 0
    lastAt = time
    guard var g = gravity else {
      gravity = (x, y, z)
      return
    }
    let slow = 1 - exp(-dt / 2)
    g.x += (x - g.x) * slow
    g.y += (y - g.y) * slow
    g.z += (z - g.z) * slow
    gravity = g
    let jolt = ((x - g.x) * (x - g.x) + (y - g.y) * (y - g.y) + (z - g.z) * (z - g.z)).squareRoot()
    motion += (jolt - motion) * (1 - exp(-dt / 1))
  }
}

/// Heart rate from the Muse 2's forehead PPG. The pulse there is weak and noisy, so
/// rather than counting peaks it looks for the repeat: once a second it autocorrelates
/// the last eight seconds and takes the strongest beat-length lag. Until the signal
/// repeats convincingly `bpm` is nil.
nonisolated struct HeartbeatDetector: Sendable {
  static let restingGuess = 66.0
  static let minimumBPM = 40.0
  static let maximumBPM = 140.0
  /// Seconds of signal each estimate looks at.
  static let window = 8.0
  /// How alike the signal must be to itself one beat later (0…1).
  static let lockAt = 0.5

  private var baseline: Double?
  private var smoothed = 0.0
  private var lastAt: Double?
  private var samples: [Double] = []
  private var times: [Double] = []
  private var estimatedAt = -Double.infinity
  private(set) var bpm: Double?
  /// The strength of the last estimate, for diagnostics.
  private(set) var confidence = 0.0

  var isLocked: Bool { bpm != nil }

  mutating func add(_ value: Double, at time: Double) {
    guard value.isFinite else { return }
    let dt = lastAt.map { min(max(time - $0, 0), 0.5) } ?? 0
    lastAt = time
    // Remove the slow drift (~1 s), then smooth the pulse (~0.05 s).
    guard let base = baseline else {
      baseline = value
      return
    }
    let drift = base + (value - base) * (1 - exp(-dt / 1))
    baseline = drift
    smoothed += (value - drift - smoothed) * (1 - exp(-dt / 0.05))
    samples.append(smoothed)
    times.append(time)
    if let first = times.firstIndex(where: { time - $0 <= Self.window }), first > 0 {
      samples.removeFirst(first)
      times.removeFirst(first)
    }
    if time - estimatedAt >= 1 {
      estimatedAt = time
      estimate()
    }
  }

  private mutating func estimate() {
    guard let first = times.first, let last = times.last, last - first >= Self.window * 0.75, samples.count > 64 else {
      bpm = nil
      return
    }
    let rate = Double(samples.count - 1) / (last - first)
    let mean = samples.reduce(0, +) / Double(samples.count)
    let centred = samples.map { $0 - mean }
    let energy = centred.reduce(0) { $0 + $1 * $1 }
    guard energy > 0 else {
      bpm = nil
      return
    }
    let count = centred.count
    let shortest = max(Int(rate * 60 / Self.maximumBPM), 1)
    let longest = min(Int(rate * 60 / Self.minimumBPM), count / 2)
    guard longest > shortest else {
      bpm = nil
      return
    }
    var similarity = [Double](repeating: 0, count: longest + 2)
    for lag in shortest...longest {
      var sum = 0.0
      for index in 0..<(count - lag) { sum += centred[index] * centred[index + lag] }
      similarity[lag] = sum / energy * Double(count) / Double(count - lag)
    }
    let best = similarity[shortest...longest].max() ?? 0
    // The first peak nearly as strong as the best, so a beat is never read as two.
    let lag = (shortest...longest).first { lag in
      similarity[lag] >= best * 0.85 && similarity[lag] >= similarity[lag - 1] && similarity[lag] >= similarity[lag + 1]
    } ?? shortest
    confidence = similarity[lag]
    bpm = confidence >= Self.lockAt ? 60 * rate / Double(lag) : nil
  }
}
#endif
