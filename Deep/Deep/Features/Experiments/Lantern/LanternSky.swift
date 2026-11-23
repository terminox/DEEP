#if EXPERIMENTS
import Foundation

// One sit, many lanterns. Every four session seconds a khom loi (the paper sky
// lantern of Yi Peng) is released for the window that just ended. Its colour, size
// and steadiness come from that window of brain data, so the finished sky is the
// whole sit, read as lanterns. Each carries a small flower on its paper, one petal
// per slice of its window (`LanternFlower`). `LanternArtView` paints them.

// MARK: - Palette (paper inks; the night lives in LanternArtView)

private struct LanternInkColorToken {
  let red: Double
  let green: Double
  let blue: Double
}

/// The warm lights a lantern's paper can take. Every lantern leans toward
/// `lanternGold`, so all of them read as Yi Peng lanterns while each one differs.
private enum LanternInkPalette {
  static let lanternGold = LanternInkColorToken(red: 1.000, green: 0.792, blue: 0.459)
  /// Alpha: a settled, relaxed mind.
  static let amberGlow = LanternInkColorToken(red: 1.000, green: 0.640, blue: 0.300)
  /// Theta: deep, drifting calm.
  static let roseLight = LanternInkColorToken(red: 0.980, green: 0.520, blue: 0.560)
  /// Beta: a busy mind burns paler.
  static let paleFlame = LanternInkColorToken(red: 1.000, green: 0.930, blue: 0.800)
  /// Low calm: a smouldering orange.
  static let emberOrange = LanternInkColorToken(red: 0.820, green: 0.420, blue: 0.200)
}

// MARK: - One lantern

/// One lantern, the portrait of one four-second window. Plain numbers, so the
/// painter decides how they look on any screen.
struct SkyLantern: Identifiable, Equatable {
  /// The window's index, k: the lantern covers session seconds 4k..<4k+4.
  let id: Int
  /// Session seconds when its window completed, 4k + 4.
  let releasedAt: Double
  /// The paper's colour, lit from inside, 0…1 each.
  let red: Double
  let green: Double
  let blue: Double
  /// Relative size, 0.7 (restless window) … 1.25 (calm window).
  let size: Double
  /// Light strength, 0.5 … 1, brighter for a calmer window.
  let glow: Double
  /// 0 restless … 1 calm. Damps the lantern's sway.
  let steadiness: Double
  /// Flame flicker, 0 … 1, a third more for each blink in its window.
  let flicker: Double
  /// Sideways wobble, 0 … 1, half for each jaw clench in its window.
  let wobble: Double
  /// Horizontal place, 0 … 1 across the sky.
  let column: Double
  /// 0 far … 1 near. Far lanterns are smaller, dimmer and settle higher.
  let depth: Double
  /// Where it settles, as a fraction of the height from the top.
  let rest: Double
  /// A private phase, 0 … 1, so no two lanterns sway in step.
  let phase: Double
  /// The flower printed on its paper: one petal per slice of the window, in order,
  /// 6 (a quiet window) … 10 (a busy one).
  let petals: [PetalTint]
  /// 0 smooth, round petals (a calm window) … 1 ruffled (a restless one).
  let ruffle: Double

  /// Neutral band powers for a window with no data.
  fileprivate static let resting = BandPowers(delta: 0.3, theta: 0.22, alpha: 0.25, beta: 0.15, gamma: 0.08)

  /// How many petals a window's flower has: more for a busier mind.
  static func petalCount(for powers: BandPowers) -> Int {
    6 + Int(LanternPetalInk.busy(powers) * 4)
  }

  /// Reads one window. The seeded draws depend only on `k`, so a lantern is the
  /// same whenever it is built.
  fileprivate init(
    index k: Int,
    window: (powers: BandPowers, calm: Double, stillness: Double)?,
    slices: [BandPowers],
    events: [EEGEvent]
  ) {
    let powers = window?.powers ?? Self.resting
    // Our calm index spans ~0.15 (restless) to ~0.85 (deep), never 0 or 1.
    let calm = min(max(((window?.calm ?? 0.5) - 0.15) / 0.7, 0), 1)
    let blinks = events.filter { $0.kind == .blink }.count
    let clenches = events.filter { $0.kind == .jawClench }.count
    var random = SeededRandom(seed: UInt64(k) &+ 1)

    id = k
    releasedAt = Double(k + 1) * LanternSky.interval
    let ink = Self.ink(powers, calm: calm)
    red = ink.red
    green = ink.green
    blue = ink.blue
    size = 0.7 + 0.55 * calm
    glow = 0.5 + 0.5 * calm
    steadiness = calm
    flicker = min(Double(blinks) / 3, 1)
    wobble = Double(min(clenches, 2)) / 2
    // The golden ratio spreads any count of lanterns evenly across the sky.
    let golden = (0.5 + Double(k) * 0.618034).truncatingRemainder(dividingBy: 1)
    column = min(max(golden + (random.unit() - 0.5) * 0.04, 0), 1)
    depth = random.unit()
    rest = 0.07 + 0.18 * depth + 0.40 * random.unit()
    phase = random.unit()
    petals = slices.map(LanternPetalInk.tint)
    ruffle = 1 - eegSmoothstep(0.18, 0.8, window?.calm ?? 0.5)
  }

  /// The band mix as a warm light: each band pulls toward its own ink, the
  /// strongest pulls hardest, and the result is mixed back toward lantern gold.
  private static func ink(_ powers: BandPowers, calm: Double) -> LanternInkColorToken {
    let pulls: [(weight: Double, ink: LanternInkColorToken)] = [
      (0.12, LanternInkPalette.lanternGold),
      (eegSmoothstep(0.14, 0.42, powers.alpha), LanternInkPalette.amberGlow),
      (eegSmoothstep(0.17, 0.36, powers.theta), LanternInkPalette.roseLight),
      (eegSmoothstep(0.05, 0.30, powers.beta), LanternInkPalette.paleFlame),
      (1 - calm, LanternInkPalette.emberOrange)
    ]
    let total = pulls.reduce(0) { $0 + $1.weight * $1.weight }
    func channel(_ value: (LanternInkColorToken) -> Double) -> Double {
      let mixed = pulls.reduce(0) { $0 + $1.weight * $1.weight * value($1.ink) } / total
      return mixed + (value(LanternInkPalette.lanternGold) - mixed) * 0.3
    }
    return LanternInkColorToken(red: channel(\.red), green: channel(\.green), blue: channel(\.blue))
  }
}

// MARK: - The sky

/// Every lantern of one sit, released one window at a time. Not observed: the
/// art advances it from inside its TimelineView, once per display frame.
@MainActor
final class LanternSky {
  /// Session seconds per lantern.
  static let interval = 4.0

  let length: Double
  private(set) var lanterns: [SkyLantern] = []

  init(length: Double) {
    self.length = length
  }

  /// How many lanterns the whole sit releases: 45, 75 or 150.
  var capacity: Int { Int(length / Self.interval) }

  /// Releases a lantern for each window the sit has completed since the last
  /// call, and returns them all. Only new windows are read, and building in steps
  /// gives the same lanterns as building at once.
  @discardableResult
  func catchUp(with sit: LiveSit) -> [SkyLantern] {
    let framesPerWindow = Int(Self.interval * LiveSit.frameRate)
    let completed = min(sit.frames.count / framesPerWindow, capacity)
    while lanterns.count < completed {
      let k = lanterns.count
      let from = Double(k) * Self.interval
      let to = from + Self.interval
      let window = sit.mean(from: from, to: to)
      // The window cut into one slice per petal.
      let count = SkyLantern.petalCount(for: window?.powers ?? SkyLantern.resting)
      let slices = (0..<count).map { j in
        let start = from + Self.interval * Double(j) / Double(count)
        let end = from + Self.interval * Double(j + 1) / Double(count)
        return sit.mean(from: start, to: end)?.powers ?? window?.powers ?? SkyLantern.resting
      }
      lanterns.append(SkyLantern(index: k, window: window, slices: slices, events: sit.events(from: from, to: to)))
    }
    return lanterns
  }
}

#endif
