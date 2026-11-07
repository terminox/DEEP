#if EXPERIMENTS
import SwiftUI

// A simulated Muse 2 headband for the Aurora experiment: one deterministic
// 10-minute meditation, shaped like the processed data LibMuse delivers
// (relative/absolute band powers at ~10 Hz, electrode fit, blink and jaw
// artifacts, plus Muse 2 heart rate and stillness). No headband is involved.
// LibMuse has no "calm" score, so `calm` is DEEP's own index: smoothed frontal
// alpha / (alpha + beta) on a soft saturating curve.
// Origin: the EEG art prototype on the `prototype/eeg-art` branch.

// MARK: - Vocabulary

enum EEGBand: Int, CaseIterable, Identifiable {
  case delta, theta, alpha, beta, gamma

  var id: Int { rawValue }

  var name: String {
    switch self {
    case .delta: "Delta"
    case .theta: "Theta"
    case .alpha: "Alpha"
    case .beta: "Beta"
    case .gamma: "Gamma"
    }
  }

  var hertz: ClosedRange<Double> {
    switch self {
    case .delta: 1...4
    case .theta: 4...8
    case .alpha: 7.5...13
    case .beta: 13...30
    case .gamma: 30...44
    }
  }
}

enum MuseChannel: Int, CaseIterable, Identifiable {
  case tp9, af7, af8, tp10

  var id: Int { rawValue }

  var name: String {
    switch self {
    case .tp9: "TP9"
    case .af7: "AF7"
    case .af8: "AF8"
    case .tp10: "TP10"
    }
  }

  var place: String {
    switch self {
    case .tp9: "Left ear"
    case .af7: "Left forehead"
    case .af8: "Right forehead"
    case .tp10: "Right ear"
    }
  }

  var isFrontal: Bool { self == .af7 || self == .af8 }
}

/// LibMuse "horseshoe" electrode fit.
enum HorseshoeFit: Int {
  case good = 1
  case ok = 2
  case bad = 4

  var label: String {
    switch self {
    case .good: "Good"
    case .ok: "OK"
    case .bad: "No contact"
    }
  }
}

/// Where the sitter is, read from the data (not the clock).
enum MeditationPhase: String, CaseIterable, Identifiable {
  case settling, drifting, wandering, deep, returning

  var id: String { rawValue }

  var label: String {
    switch self {
    case .settling: "Settling in"
    case .drifting: "Relaxing"
    case .wandering: "Mind wandering"
    case .deep: "Deep calm"
    case .returning: "Coming back"
    }
  }
}

enum EEGArtifactKind: String {
  case blink
  case jawClench

  var label: String {
    switch self {
    case .blink: "Blink"
    case .jawClench: "Jaw clench"
    }
  }
}

struct EEGEvent: Identifiable, Hashable {
  let id: Int
  let kind: EEGArtifactKind
  /// Session seconds.
  let time: Double
}

// MARK: - Band powers

struct BandPowers: Equatable {
  var delta: Double
  var theta: Double
  var alpha: Double
  var beta: Double
  var gamma: Double

  static let zero = BandPowers(delta: 0, theta: 0, alpha: 0, beta: 0, gamma: 0)

  subscript(band: EEGBand) -> Double {
    get {
      switch band {
      case .delta: delta
      case .theta: theta
      case .alpha: alpha
      case .beta: beta
      case .gamma: gamma
      }
    }
    set {
      switch band {
      case .delta: delta = newValue
      case .theta: theta = newValue
      case .alpha: alpha = newValue
      case .beta: beta = newValue
      case .gamma: gamma = newValue
      }
    }
  }

  var dominant: EEGBand {
    EEGBand.allCases.max { self[$0] < self[$1] } ?? .alpha
  }

  func mixed(with other: BandPowers, _ amount: Double) -> BandPowers {
    var result = self
    for band in EEGBand.allCases {
      result[band] = self[band] + (other[band] - self[band]) * amount
    }
    return result
  }

  static func + (lhs: BandPowers, rhs: BandPowers) -> BandPowers {
    var result = lhs
    for band in EEGBand.allCases { result[band] += rhs[band] }
    return result
  }

  static func / (lhs: BandPowers, rhs: Double) -> BandPowers {
    var result = lhs
    for band in EEGBand.allCases { result[band] /= rhs }
    return result
  }
}

// MARK: - One processed sample (the ~10 Hz LibMuse stream, plus Muse 2 extras)

struct EEGFrame: Equatable {
  /// Session seconds.
  var time: Double
  /// Relative band powers, averaged over the four channels. Sum to 1.
  var relative: BandPowers
  /// Absolute band powers (log10 scale, like LibMuse), channel average.
  var absolute: BandPowers
  /// Relative alpha per channel, TP9 · AF7 · AF8 · TP10.
  var channelAlpha: [Double]
  /// Electrode fit per channel, TP9 · AF7 · AF8 · TP10.
  var fit: [HorseshoeFit]
  /// From PPG.
  var heartRate: Double
  /// From the accelerometer, 0 fidgeting … 1 perfectly still.
  var stillness: Double
  /// OUR index, not Muse's: smoothed frontal α / (α + β), mapped to 0…1.
  var calm: Double
  var phase: MeditationPhase
  /// An artifact landed within this frame.
  var blink: Bool
  var jawClench: Bool

  /// Frontal alpha asymmetry, ln(AF8 α) − ln(AF7 α). Positive leans "approach".
  var frontalAsymmetry: Double {
    log(max(channelAlpha[2], 0.001)) - log(max(channelAlpha[1], 0.001))
  }

  func mixed(with other: EEGFrame, _ amount: Double) -> EEGFrame {
    var result = amount < 0.5 ? self : other
    result.time = time + (other.time - time) * amount
    result.relative = relative.mixed(with: other.relative, amount)
    result.absolute = absolute.mixed(with: other.absolute, amount)
    result.channelAlpha = zip(channelAlpha, other.channelAlpha).map { $0 + ($1 - $0) * amount }
    result.heartRate = heartRate + (other.heartRate - heartRate) * amount
    result.stillness = stillness + (other.stillness - stillness) * amount
    result.calm = calm + (other.calm - calm) * amount
    return result
  }
}

// MARK: - People

/// Three sitters, so the client sees the art change with the person.
enum EEGPerson: String, CaseIterable, Identifiable {
  case firstTime, regular, experienced

  var id: String { rawValue }

  var label: String {
    switch self {
    case .firstTime: "First time"
    case .regular: "Regular"
    case .experienced: "Experienced"
    }
  }

  var profile: EEGProfile {
    switch self {
    case .firstTime:
      EEGProfile(
        seed: 11, alphaGain: 0.4, thetaGain: 0.15, restlessness: 1.0,
        wanders: [(150, 55), (290, 70), (430, 60), (520, 40)],
        blinksPerMinute: (14, 8), jawClenches: 7,
        heartRate: (82, 76), stillness: (0.45, 0.7), fitSettle: 45
      )
    case .regular:
      EEGProfile(
        seed: 23, alphaGain: 1.1, thetaGain: 0.45, restlessness: 0.5,
        wanders: [(250, 55), (470, 25)],
        blinksPerMinute: (10, 4), jawClenches: 3,
        heartRate: (76, 66), stillness: (0.65, 0.9), fitSettle: 22
      )
    case .experienced:
      EEGProfile(
        seed: 37, alphaGain: 1.6, thetaGain: 1.0, restlessness: 0.25,
        wanders: [(330, 20)],
        blinksPerMinute: (7, 1.5), jawClenches: 1,
        heartRate: (68, 57), stillness: (0.85, 0.98), fitSettle: 10
      )
    }
  }
}

struct EEGProfile {
  var seed: UInt64
  /// How strongly alpha rises as the sitter relaxes.
  var alphaGain: Double
  /// How strongly theta rises in deep calm.
  var thetaGain: Double
  /// Baseline beta (busy mind), 0…1.
  var restlessness: Double
  /// Mind-wandering episodes: (start seconds, length seconds).
  var wanders: [(Double, Double)]
  /// Blinks per minute at the start and at the end.
  var blinksPerMinute: (Double, Double)
  var jawClenches: Int
  var heartRate: (Double, Double)
  var stillness: (Double, Double)
  /// Seconds until all four electrodes read "good".
  var fitSettle: Double
}

// MARK: - Deterministic noise

/// Small seeded RNG (SplitMix64) so the same person always yields the same
/// session, and the same flower.
struct SeededRandom: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 1 }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// Smooth 1-D value noise in −1…1, continuous in `x`.
func eegNoise(_ x: Double, seed: UInt64) -> Double {
  func hash(_ i: Int64) -> Double {
    var z = UInt64(bitPattern: i) &+ seed &* 0x9E37_79B9_7F4A_7C15
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    z = z ^ (z >> 31)
    return Double(z >> 11) / Double(1 << 53) * 2 - 1
  }
  let i = Int64(floor(x))
  let f = x - floor(x)
  let s = f * f * (3 - 2 * f)
  return hash(i) + (hash(i + 1) - hash(i)) * s
}

private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
  let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
  return t * t * (3 - 2 * t)
}

// MARK: - The recorded session

/// A whole 10-minute sit, sampled at `frameRate`. The "after" screens read it
/// whole; the live player walks through it.
struct EEGSessionRecording {
  static let duration: Double = 600

  let person: EEGPerson?
  let profile: EEGProfile
  let frameRate: Double
  let frames: [EEGFrame]
  let events: [EEGEvent]

  init(person: EEGPerson) {
    self.init(profile: person.profile, person: person, frameRate: 10)
  }

  init(profile: EEGProfile, person: EEGPerson? = nil, frameRate: Double) {
    self.person = person
    self.profile = profile
    self.frameRate = frameRate
    let events = Self.makeEvents(profile)
    self.events = events
    self.frames = Self.makeFrames(profile, frameRate: frameRate, events: events)
  }

  /// Interpolated frame at a session time.
  func frame(at time: Double) -> EEGFrame {
    let position = min(max(time, 0), Self.duration) * frameRate
    let index = min(Int(position), frames.count - 1)
    let next = min(index + 1, frames.count - 1)
    return frames[index].mixed(with: frames[next], position - Double(index))
  }

  // MARK: Generation

  private static func makeEvents(_ profile: EEGProfile) -> [EEGEvent] {
    var random = SeededRandom(seed: profile.seed &+ 101)
    var events: [EEGEvent] = []
    var time = 2.0
    while time < duration {
      let progress = time / duration
      let rate = profile.blinksPerMinute.0
        + (profile.blinksPerMinute.1 - profile.blinksPerMinute.0) * smoothstep(0, 0.5, progress)
      let wandering = profile.wanders.contains { time >= $0.0 && time < $0.0 + $0.1 }
      let perMinute = rate * (wandering ? 1.8 : 1)
      events.append(EEGEvent(id: events.count, kind: .blink, time: time))
      time += 60 / perMinute * (0.4 + random.unit() * 1.2)
    }
    // Jaw clenches cluster in the restless moments: the start and the wanders.
    let anchors = [(20.0, 60.0)] + profile.wanders
    for clench in 0..<profile.jawClenches {
      let anchor = anchors[clench % anchors.count]
      let at = anchor.0 + random.unit() * anchor.1
      events.append(EEGEvent(id: events.count, kind: .jawClench, time: at))
    }
    return events.sorted { $0.time < $1.time }
      .enumerated()
      .map { EEGEvent(id: $0.offset, kind: $0.element.kind, time: $0.element.time) }
  }

  private static func makeFrames(
    _ profile: EEGProfile,
    frameRate: Double,
    events: [EEGEvent]
  ) -> [EEGFrame] {
    let count = Int(duration * frameRate) + 1
    let dt = 1 / frameRate
    let seed = profile.seed
    var frames: [EEGFrame] = []
    frames.reserveCapacity(count)
    var smoothedRatio = 0.4
    var smoothedTheta = 0.0
    var eventIndex = 0

    for step in 0..<count {
      let t = Double(step) * dt

      // How far into letting go the sitter is: relaxes over ~4 min, eases back
      // up in the last minute.
      let relax = smoothstep(40, 260, t) * (1 - 0.45 * smoothstep(540, 600, t))
      let deep = smoothstep(280, 420, t) * (1 - smoothstep(520, 590, t))
      let wander = profile.wanders.reduce(0.0) { level, episode in
        let rise = smoothstep(episode.0, episode.0 + 8, t)
        let fall = 1 - smoothstep(episode.0 + episode.1 - 10, episode.0 + episode.1, t)
        return max(level, rise * fall)
      }
      let settled = relax * (1 - 0.85 * wander)

      func drift(_ band: Double, _ speed: Double = 0.06) -> Double {
        1 + 0.12 * eegNoise(t * speed + band * 17, seed: seed)
          + 0.05 * eegNoise(t * speed * 5 + band * 31, seed: seed)
      }

      // Linear band powers (µV²-ish), before normalising.
      var linear = BandPowers(
        delta: 4.2 * drift(0) * (1 + 0.25 * deep * profile.thetaGain),
        theta: 2.4 * drift(1) * (1 + 2.6 * deep * profile.thetaGain * (1 - wander)),
        alpha: 2.0 * drift(2) * (1 + 1.5 * settled * profile.alphaGain),
        beta: 2.2 * drift(3) * (0.7 + 0.8 * profile.restlessness) * (1 - 0.45 * settled) * (1 + 1.1 * wander),
        gamma: 0.6 * drift(4, 0.2) * (0.8 + 0.6 * profile.restlessness) * (1 + 0.6 * wander)
      )

      // Artifacts landing in this frame.
      var blink = false
      var clench = false
      while eventIndex < events.count, events[eventIndex].time < t + dt {
        if events[eventIndex].time >= t {
          if events[eventIndex].kind == .blink { blink = true } else { clench = true }
        }
        eventIndex += 1
      }
      // A blink floods delta; a clench floods gamma and beta (muscle, not mind).
      let nearClench = events.contains { $0.kind == .jawClench && abs($0.time + 0.4 - t) < 0.6 }
      if nearClench {
        linear.gamma *= 5
        linear.beta *= 1.8
      }
      if events.contains(where: { $0.kind == .blink && abs($0.time - t) < 0.2 }) {
        linear.delta *= 1.9
      }

      let total = EEGBand.allCases.reduce(0) { $0 + linear[$1] }
      let relative = linear / total
      var absolute = BandPowers.zero
      for band in EEGBand.allCases { absolute[band] = log10(linear[band] * 1.4) }

      // Temporal sites carry more alpha than the forehead; a slight
      // right-frontal lean as the sitter relaxes.
      let channelAlpha = MuseChannel.allCases.map { channel -> Double in
        let site = channel.isFrontal ? 0.85 : 1.12
        let lean = channel == .af8 ? 1 + 0.06 * settled : 1
        return relative.alpha * site * lean * (1 + 0.04 * eegNoise(t * 0.3 + Double(channel.rawValue) * 9, seed: seed))
      }

      // Our calm index: frontal alpha against beta, smoothed over ~4 s.
      let frontalAlpha = (channelAlpha[1] + channelAlpha[2]) / 2
      let ratio = frontalAlpha / (frontalAlpha + relative.beta)
      let smoothing = 1 - exp(-dt / 4)
      smoothedRatio += (ratio - smoothedRatio) * smoothing
      smoothedTheta += (relative.theta - smoothedTheta) * smoothing
      // Saturates softly, so a very settled sitter still has headroom.
      let calm = 1 - exp(-1.7 * max(smoothedRatio - 0.3, 0) / 0.5)

      let fit = MuseChannel.allCases.map { channel -> HorseshoeFit in
        let settleAt = profile.fitSettle * (channel.isFrontal ? 0.6 : 1.0 + 0.2 * Double(channel.rawValue % 2))
        if t < settleAt * 0.4 { return channel.isFrontal ? .ok : .bad }
        if t < settleAt { return .ok }
        return .good
      }

      let heartRate = profile.heartRate.0
        + (profile.heartRate.1 - profile.heartRate.0) * smoothstep(0, 480, t)
        + 4 * wander
        + 1.2 * eegNoise(t * 0.15, seed: seed &+ 7)
      let fidget = max(0, eegNoise(t * 0.4, seed: seed &+ 9)) * (1 - settled)
      let stillness = min(max(
        profile.stillness.0 + (profile.stillness.1 - profile.stillness.0) * relax
          - 0.25 * wander - 0.3 * fidget,
        0), 1)

      let phase: MeditationPhase
      if t < 75 {
        phase = .settling
      } else if t > 545 {
        phase = .returning
      } else if wander > 0.5 || calm < 0.3 {
        phase = .wandering
      } else if calm > 0.62, smoothedTheta > 0.2 {
        phase = .deep
      } else {
        phase = .drifting
      }

      frames.append(EEGFrame(
        time: t,
        relative: relative,
        absolute: absolute,
        channelAlpha: channelAlpha,
        fit: fit,
        heartRate: heartRate,
        stillness: stillness,
        calm: calm,
        phase: phase,
        blink: blink,
        jawClench: clench
      ))
    }
    return frames
  }
}

struct LiveArtifact: Hashable {
  let kind: EEGArtifactKind
  /// Wall-clock seconds (timeIntervalSinceReferenceDate) the artifact fired.
  let wallTime: Double
}

// MARK: - Live player

/// Walks a recording in compressed time (10 minutes in 2.5) and turns crossed
/// events into wall-clock artifacts. At the end of the sit it starts again from
/// the top, forever, so the demo plays until someone leaves. For 60 Hz visuals
/// read `frame(at:)` inside a TimelineView; `liveArtifacts` updates at 10 Hz.
@MainActor
@Observable
final class EEGSessionPlayer {
  /// Session seconds per wall second.
  static let speed = 4.0

  let recording: EEGSessionRecording
  private(set) var liveArtifacts: [LiveArtifact] = []

  @ObservationIgnored private var anchorWall = Date()
  @ObservationIgnored private var lastTime: Double = 0
  @ObservationIgnored private var nextEvent = 0
  @ObservationIgnored private var ticker: Task<Void, Never>?

  init(recording: EEGSessionRecording) {
    self.recording = recording
  }

  /// Session seconds at a wall-clock date, wrapping at the end of the sit.
  func sessionTime(at date: Date) -> Double {
    let elapsed = max(date.timeIntervalSince(anchorWall), 0) * Self.speed
    return elapsed.truncatingRemainder(dividingBy: EEGSessionRecording.duration)
  }

  func frame(at date: Date) -> EEGFrame {
    recording.frame(at: sessionTime(at: date))
  }

  func start() {
    guard ticker == nil else { return }
    anchorWall = Date()
    lastTime = 0
    nextEvent = 0
    liveArtifacts = []
    ticker = Task { [weak self] in
      while !Task.isCancelled {
        self?.tick()
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  func stop() {
    ticker?.cancel()
    ticker = nil
  }

  private func tick() {
    let now = Date()
    let time = sessionTime(at: now)
    let wall = now.timeIntervalSinceReferenceDate
    // The sit wrapped around: start reading events from the top again.
    if time < lastTime { nextEvent = 0 }
    lastTime = time
    let events = recording.events
    while nextEvent < events.count, events[nextEvent].time <= time {
      // Place the artifact at the wall moment the session crossed it.
      let behind = (time - events[nextEvent].time) / Self.speed
      liveArtifacts.append(LiveArtifact(kind: events[nextEvent].kind, wallTime: wall - behind))
      nextEvent += 1
    }
    liveArtifacts.removeAll { wall - $0.wallTime > 8 }
  }
}

extension EEGSessionRecording {
  /// The sit the Aurora experiment plays: a regular meditator, built once.
  static let regular = EEGSessionRecording(person: .regular)
}

#endif
