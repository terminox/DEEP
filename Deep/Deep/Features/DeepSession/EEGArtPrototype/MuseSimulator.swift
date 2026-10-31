#if DEBUG
import SwiftUI

// PROTOTYPE — throwaway, DEBUG only.
// A simulated Muse 2 headband: one deterministic 10-minute meditation per
// person, shaped like the data LibMuse actually delivers, so the three art
// variants are judged against real-shaped signals instead of random noise.
//
// What LibMuse gives an app (Muse SDK overview + Muse Lab guide + the Muse
// Direct OSC layout; check names against the LibMuse headers in the real build):
// - Raw EEG, 4 channels TP9 · AF7 · AF8 · TP10, µV, 256 Hz
// - Absolute band powers δ θ α β γ per channel (log scale), ~10 Hz
// - Relative band powers (0–1, sum to 1), ~10 Hz
// - Electrode fit ("horseshoe"): 1 good, 2 ok, 4 bad, per channel
// - Artifacts: headband on, blink, jaw clench
// - Muse 2 extras: PPG (3 ch, 64 Hz → heart rate), accelerometer (~52 Hz)
// It does NOT give the Muse app's "calm" score, so `calm` here is our own
// index (smoothed frontal α / (α + β)); every screen must say so.
// Plan: ~/.claude/plans/my-client-would-like-staged-sphinx.md

// MARK: - Palette (prototype-local source of truth)

private struct EEGColorToken {
  let red: Double
  let green: Double
  let blue: Double
  var color: Color { Color(red: red, green: green, blue: blue) }
}

/// Band colours, shared by every variant so "alpha" is one colour everywhere.
private enum EEGPalette {
  static let delta = EEGColorToken(red: 0.420, green: 0.478, blue: 0.784) // dusk indigo
  static let theta = EEGColorToken(red: 0.663, green: 0.494, blue: 0.851) // violet
  static let alpha = EEGColorToken(red: 0.388, green: 0.769, blue: 0.659) // aurora green
  static let beta  = EEGColorToken(red: 0.929, green: 0.565, blue: 0.565) // warm rose
  static let gamma = EEGColorToken(red: 0.957, green: 0.784, blue: 0.447) // gold
}

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

  var symbol: String {
    switch self {
    case .delta: "δ"
    case .theta: "θ"
    case .alpha: "α"
    case .beta: "β"
    case .gamma: "γ"
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

  /// One line a curious person can take away. Plain, hedged, not medical.
  var meaning: String {
    switch self {
    case .delta: "Deep sleep and very slow rhythms. Also picks up eye movement."
    case .theta: "Drowsy, dreamy, inward attention. Often rises in deep meditation."
    case .alpha: "Relaxed but awake. Grows when you close your eyes and let go."
    case .beta: "Active thinking, planning, focus, a busy mind."
    case .gamma: "Fast activity. On a headband it is mostly muscle tension."
    }
  }

  var tint: Color {
    switch self {
    case .delta: EEGPalette.delta.color
    case .theta: EEGPalette.theta.color
    case .alpha: EEGPalette.alpha.color
    case .beta: EEGPalette.beta.color
    case .gamma: EEGPalette.gamma.color
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

  /// One frame per second, 600 of them, for charts and timelines.
  var seconds: [EEGFrame] {
    stride(from: 0, to: frames.count, by: max(Int(frameRate), 1)).map { frames[$0] }
  }

  /// Ten one-minute summaries, the flower's rings.
  var minutes: [EEGMinute] {
    (0..<10).map { minute in
      let lower = Double(minute) * 60
      let slice = frames.filter { $0.time >= lower && $0.time < lower + 60 }
      let count = Double(max(slice.count, 1))
      let relative = slice.reduce(BandPowers.zero) { $0 + $1.relative } / count
      let phases = Dictionary(grouping: slice, by: \.phase)
      return EEGMinute(
        index: minute,
        relative: relative,
        calm: slice.map(\.calm).reduce(0, +) / count,
        heartRate: slice.map(\.heartRate).reduce(0, +) / count,
        stillness: slice.map(\.stillness).reduce(0, +) / count,
        blinks: events.filter { $0.kind == .blink && $0.time >= lower && $0.time < lower + 60 }.count,
        jawClenches: events.filter { $0.kind == .jawClench && $0.time >= lower && $0.time < lower + 60 }.count,
        phase: phases.max { $0.value.count < $1.value.count }?.key ?? .drifting
      )
    }
  }

  var summary: EEGSessionSummary { EEGSessionSummary(self) }

  /// A 1–44 Hz power spectrum (linear, unnormalised) for a frame, built from
  /// its band powers over a 1/f floor. For spectrograms.
  static func spectrum(of frame: EEGFrame, bins: Int = 44) -> [Double] {
    (0..<bins).map { bin in
      let hz = Double(bin) + 1
      var power = 0.6 / hz
      for band in EEGBand.allCases {
        let range = band.hertz
        let centre = (range.lowerBound + range.upperBound) / 2
        let width = (range.upperBound - range.lowerBound) / 2
        let distance = (hz - centre) / width
        power += pow(10, frame.absolute[band]) * exp(-distance * distance * 1.6) / width
      }
      return power
    }
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

struct EEGMinute: Identifiable {
  let index: Int
  let relative: BandPowers
  let calm: Double
  let heartRate: Double
  let stillness: Double
  let blinks: Int
  let jawClenches: Int
  let phase: MeditationPhase

  var id: Int { index }
}

// MARK: - The facts an "after" screen can stand on

struct EEGSessionSummary {
  /// Mean relative alpha over the first two minutes.
  let baselineAlpha: Double
  /// Best 3-minute mean relative alpha, and when it started (seconds).
  let peakAlpha: Double
  let peakAlphaStart: Double
  /// Percent the peak window sits above baseline.
  var alphaRisePercent: Int { Int(((peakAlpha / max(baselineAlpha, 0.001)) - 1) * 100) }
  /// Seconds spent in each phase.
  let timeInPhase: [MeditationPhase: Double]
  let wanderEpisodes: Int
  let blinks: Int
  let jawClenches: Int
  let heartRateStart: Double
  let heartRateEnd: Double
  let averageCalm: Double
  let averageStillness: Double
  let thetaRisePercent: Int

  init(_ recording: EEGSessionRecording) {
    let seconds = recording.seconds
    func mean(_ slice: ArraySlice<EEGFrame>, _ value: (EEGFrame) -> Double) -> Double {
      slice.isEmpty ? 0 : slice.map(value).reduce(0, +) / Double(slice.count)
    }
    baselineAlpha = mean(seconds[0..<120]) { $0.relative.alpha }
    var bestAlpha = 0.0
    var bestStart = 0.0
    for start in stride(from: 60, through: seconds.count - 180, by: 10) {
      let value = mean(seconds[start..<(start + 180)]) { $0.relative.alpha }
      if value > bestAlpha {
        bestAlpha = value
        bestStart = Double(start)
      }
    }
    peakAlpha = bestAlpha
    peakAlphaStart = bestStart

    var phases: [MeditationPhase: Double] = [:]
    var episodes = 0
    var previous: MeditationPhase?
    for frame in seconds {
      phases[frame.phase, default: 0] += 1
      if frame.phase == .wandering, previous != .wandering { episodes += 1 }
      previous = frame.phase
    }
    timeInPhase = phases
    wanderEpisodes = episodes
    blinks = recording.events.filter { $0.kind == .blink }.count
    jawClenches = recording.events.filter { $0.kind == .jawClench }.count
    heartRateStart = mean(seconds[0..<60]) { $0.heartRate }
    heartRateEnd = mean(seconds[(seconds.count - 60)...]) { $0.heartRate }
    averageCalm = mean(seconds[...]) { $0.calm }
    averageStillness = mean(seconds[...]) { $0.stillness }
    let thetaBase = mean(seconds[0..<120]) { $0.relative.theta }
    let thetaPeak = mean(seconds[330..<480]) { $0.relative.theta }
    thetaRisePercent = Int((thetaPeak / max(thetaBase, 0.001) - 1) * 100)
  }
}

// MARK: - Raw 256 Hz signal

/// The raw EEG a headband would stream, synthesised on demand from a frame's
/// band powers. Deterministic in wall time, so a scrolling trace is just a
/// window of this function. Values are µV around 0 (LibMuse offsets them).
enum MuseRawSignal {
  static let sampleRate: Double = 256

  /// Frequencies (Hz) mixed inside each band, per channel phase offset.
  private static let components: [(EEGBand, Double, Double)] = [
    (.delta, 1.6, 0.0), (.delta, 2.9, 1.3),
    (.theta, 5.2, 0.7), (.theta, 6.6, 2.1),
    (.alpha, 9.4, 0.3), (.alpha, 10.3, 1.9), (.alpha, 11.1, 2.8),
    (.beta, 15.5, 0.5), (.beta, 19.2, 1.1), (.beta, 24.7, 2.4),
    (.gamma, 33.0, 0.9), (.gamma, 39.5, 2.2)
  ]

  /// One sample. `artifacts` are recent artifacts in wall seconds.
  static func sample(
    channel: MuseChannel,
    wallTime: Double,
    frame: EEGFrame,
    artifacts: [LiveArtifact]
  ) -> Double {
    let c = Double(channel.rawValue)
    let alphaSite = frame.channelAlpha[channel.rawValue] / max(frame.relative.alpha, 0.001)
    var value = 0.0
    for (band, hz, phase) in components {
      // Slow amplitude and phase wander make it read as EEG, not a synth pad.
      let wobble = 1 + 0.45 * eegNoise(wallTime * 1.7 + hz + c * 5, seed: 3)
      let jitter = 0.9 * eegNoise(wallTime * 0.8 + hz * 3 + c, seed: 5)
      var amplitude = 7.5 * sqrt(pow(10, frame.absolute[band])) * wobble
      if band == .alpha { amplitude *= alphaSite }
      value += amplitude * sin(2 * .pi * hz * wallTime + phase + c * 0.9 + jitter)
    }
    value += 4 * eegNoise(wallTime * 90 + c * 13, seed: 8)
    if frame.fit[channel.rawValue] == .bad {
      value = value * 0.3 + 45 * eegNoise(wallTime * 3 + c, seed: 12) + 25 * sin(2 * .pi * 50 * wallTime)
    }
    for artifact in artifacts {
      let age = wallTime - artifact.wallTime
      switch artifact.kind {
      case .blink where channel.isFrontal:
        // A blink is a big slow bump on the forehead sensors.
        let shape = exp(-pow((age - 0.16) / 0.09, 2))
        value += 130 * shape * (channel == .af7 ? 1 : 0.92)
      case .jawClench where age >= 0 && age < 0.9:
        // A clench is a burst of fast muscle noise, strongest by the ears.
        let envelope = sin(.pi * age / 0.9)
        let gain = channel.isFrontal ? 22.0 : 38.0
        value += gain * envelope * eegNoise(wallTime * 260 + c * 7, seed: 21)
      default:
        break
      }
    }
    return value
  }
}

struct LiveArtifact: Hashable {
  let kind: EEGArtifactKind
  /// Wall-clock seconds (timeIntervalSinceReferenceDate) the artifact fired.
  let wallTime: Double
}

// MARK: - Live player

/// Walks a recording in compressed time (10 minutes in about 2.5) and turns
/// crossed events into wall-clock artifacts for the raw signal. `current`
/// updates at 10 Hz; for 60 Hz visuals use `frame(at:)` inside a TimelineView.
@MainActor
@Observable
final class EEGSessionPlayer {
  enum Speed: Double, CaseIterable, Identifiable {
    case calm = 4
    case quick = 20

    var id: Double { rawValue }
    var label: String { "\(Int(rawValue))×" }
  }

  let recording: EEGSessionRecording
  private(set) var sessionTime: Double = 0
  private(set) var current: EEGFrame
  private(set) var liveArtifacts: [LiveArtifact] = []
  var speed: Speed {
    didSet { reanchor() }
  }
  var isFinished: Bool { sessionTime >= EEGSessionRecording.duration }
  var progress: Double { sessionTime / EEGSessionRecording.duration }

  @ObservationIgnored private var anchorWall = Date()
  @ObservationIgnored private var anchorSession: Double = 0
  @ObservationIgnored private var nextEvent = 0
  @ObservationIgnored private var ticker: Task<Void, Never>?

  init(recording: EEGSessionRecording, speed: Speed = .calm, startAt: Double = 0) {
    self.recording = recording
    self.speed = speed
    self.anchorSession = startAt
    self.sessionTime = startAt
    self.current = recording.frame(at: startAt)
    self.nextEvent = recording.events.firstIndex { $0.time >= startAt } ?? recording.events.count
  }

  /// Session seconds at a wall-clock date.
  func sessionTime(at date: Date) -> Double {
    min(anchorSession + date.timeIntervalSince(anchorWall) * speed.rawValue, EEGSessionRecording.duration)
  }

  func frame(at date: Date) -> EEGFrame {
    recording.frame(at: sessionTime(at: date))
  }

  func start() {
    guard ticker == nil else { return }
    reanchor()
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

  func restart() {
    stop()
    anchorSession = 0
    sessionTime = 0
    nextEvent = 0
    liveArtifacts = []
    current = recording.frame(at: 0)
    start()
  }

  private func reanchor() {
    anchorSession = sessionTime
    anchorWall = Date()
  }

  private func tick() {
    let now = Date()
    let time = sessionTime(at: now)
    let wall = now.timeIntervalSinceReferenceDate
    let events = recording.events
    while nextEvent < events.count, events[nextEvent].time <= time {
      // Place the artifact at the wall moment the session crossed it.
      let behind = (time - events[nextEvent].time) / speed.rawValue
      liveArtifacts.append(LiveArtifact(kind: events[nextEvent].kind, wallTime: wall - behind))
      nextEvent += 1
    }
    liveArtifacts.removeAll { wall - $0.wallTime > 8 }
    sessionTime = time
    current = recording.frame(at: time)
  }
}

// MARK: - A group sit (for the Yi Peng piece)

struct EEGParticipant: Identifiable {
  let id: Int
  let name: String
  /// Session seconds they joined.
  let joinedAt: Double
  /// Their own sit at 1 Hz.
  let recording: EEGSessionRecording
  /// A per-person hue offset so two "Regulars" still look like two people.
  let hueShift: Double

  func frame(at time: Double) -> EEGFrame? {
    guard time >= joinedAt else { return nil }
    return recording.frame(at: time - joinedAt)
  }
}

enum EEGGroupSession {
  private static let names = [
    "Ploy", "Nam", "Mint", "Fah", "Pim", "Nok", "Joy", "Beam", "Tong", "Ice",
    "Earth", "Kaew", "Fern", "Pun", "Bow", "Noon", "Toey", "Win", "Gam", "May",
    "Oil", "Palm", "Kwan", "Aom", "Bank", "Jane", "Ton", "Pear", "Mook", "Film",
    "Bee", "New", "Bua", "Tan", "Yok", "Pond", "Air", "Fon", "Ying", "Mon",
    "Ann", "Ping", "Tai", "Oat", "Jeab", "Nut", "Pang", "Som"
  ]

  /// `count` simulated sitters joining across the first two minutes, a mix of
  /// first-timers, regulars and experienced meditators.
  static func participants(count: Int = 36, seed: UInt64 = 2026) -> [EEGParticipant] {
    var random = SeededRandom(seed: seed)
    return (0..<min(count, names.count)).map { index in
      let base = EEGPerson.allCases[Int(random.unit() * 3) % 3].profile
      var profile = base
      profile.seed = seed &+ UInt64(index) &* 977
      profile.alphaGain *= 0.75 + random.unit() * 0.5
      profile.thetaGain *= 0.7 + random.unit() * 0.6
      profile.restlessness = min(max(profile.restlessness + (random.unit() - 0.5) * 0.3, 0), 1)
      profile.wanders = profile.wanders.map { ($0.0 + (random.unit() - 0.5) * 80, $0.1) }
      return EEGParticipant(
        id: index,
        name: names[index],
        joinedAt: index == 0 ? 0 : random.unit() * 120,
        recording: EEGSessionRecording(profile: profile, frameRate: 1),
        hueShift: random.unit() * 2 - 1
      )
    }
  }
}

// MARK: - Preview fixtures

extension EEGSessionRecording {
  /// Built once per person; previews and variants share them.
  @MainActor static let fixtures: [EEGPerson: EEGSessionRecording] = Dictionary(
    uniqueKeysWithValues: EEGPerson.allCases.map { ($0, EEGSessionRecording(person: $0)) }
  )

  @MainActor static func fixture(_ person: EEGPerson) -> EEGSessionRecording {
    fixtures[person] ?? EEGSessionRecording(person: person)
  }
}

#Preview("Simulated session") {
  let recording = EEGSessionRecording.fixture(.regular)
  let summary = recording.summary
  ScrollView {
    VStack(alignment: .leading, spacing: 8) {
      Text("Alpha +\(summary.alphaRisePercent)% at \(Int(summary.peakAlphaStart / 60)) min")
      Text("HR \(Int(summary.heartRateStart)) → \(Int(summary.heartRateEnd))")
      Text("Blinks \(summary.blinks), clenches \(summary.jawClenches), wanders \(summary.wanderEpisodes)")
      ForEach(recording.minutes) { minute in
        HStack(spacing: 2) {
          ForEach(EEGBand.allCases) { band in
            Rectangle()
              .fill(band.tint)
              .frame(width: minute.relative[band] * 300, height: 14)
          }
          Text(minute.phase.label).font(.caption2)
        }
      }
    }
    .padding()
  }
}
#endif
