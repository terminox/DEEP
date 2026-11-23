#if EXPERIMENTS
import SwiftUI

// The small flower printed on every lantern's paper, as in the prototype's Yi Peng
// exhibition. Each petal is one slice of the lantern's four seconds, coloured by the
// band mix of that slice: alpha-led petals lean green, theta-led violet, a busy
// (beta-led) slice rose. A busier window grows more petals; a calm one keeps them
// smooth and round, a restless one ruffles them.
// Origin: `PetalInk` and `petalPaths` in the EEG art prototype (`prototype/eeg-art`).

// MARK: - Palette (petal inks)

private struct PetalBandColorToken {
  let red: Double
  let green: Double
  let blue: Double

  /// The token's hue, 0…1, read once.
  var hue: Double {
    let high = max(red, green, blue)
    let low = min(red, green, blue)
    let spread = high - low
    guard spread > 0 else { return 0 }
    let sector: Double
    if high == red {
      sector = (green - blue) / spread
    } else if high == green {
      sector = 2 + (blue - red) / spread
    } else {
      sector = 4 + (red - green) / spread
    }
    return lanternFraction(sector / 6)
  }
}

/// The band colours the prototype gave every variant, so "alpha" is one colour.
private enum PetalBandPalette {
  static let auroraGreen = PetalBandColorToken(red: 0.388, green: 0.769, blue: 0.659)
  static let violetDrift = PetalBandColorToken(red: 0.663, green: 0.494, blue: 0.851)
  static let warmRose = PetalBandColorToken(red: 0.929, green: 0.565, blue: 0.565)
}

// MARK: - Petal colour

/// One petal's light, plain numbers so a lantern stays a value.
nonisolated struct PetalTint: Equatable, Sendable {
  let red: Double
  let green: Double
  let blue: Double
}

nonisolated enum LanternPetalInk {
  private static let alphaHue = PetalBandPalette.auroraGreen.hue
  private static let thetaHue = PetalBandPalette.violetDrift.hue
  private static let betaHue = PetalBandPalette.warmRose.hue

  /// 0 quiet … 1 beta-led (a busy mind).
  static func busy(_ powers: BandPowers) -> Double {
    eegSmoothstep(0.10, 0.46, powers.beta / max(powers.alpha + powers.theta + powers.beta, 0.001))
  }

  /// 0 alpha-led … 1 theta-led.
  static func thetaLean(_ powers: BandPowers) -> Double {
    eegSmoothstep(0.28, 0.56, powers.theta / max(powers.alpha + powers.theta, 0.001))
  }

  /// A slice's band mix as a petal colour: the prototype's rule, a touch richer so
  /// it prints on lantern paper.
  static func tint(_ powers: BandPowers) -> PetalTint {
    let busy = busy(powers)
    var hue = lerpHue(alphaHue, thetaHue, thetaLean(powers))
    hue = lerpHue(hue, betaHue, busy * 0.8)
    return rgb(hue: hue, saturation: 0.39 + 0.05 * (1 - busy), brightness: 0.96)
  }

  private static func lerpHue(_ from: Double, _ to: Double, _ amount: Double) -> Double {
    var delta = to - from
    if delta > 0.5 { delta -= 1 } else if delta < -0.5 { delta += 1 }
    return lanternFraction(from + delta * amount)
  }

  private static func rgb(hue: Double, saturation: Double, brightness: Double) -> PetalTint {
    let sector = lanternFraction(hue) * 6
    let chroma = brightness * saturation
    let second = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
    let base = brightness - chroma
    let (r, g, b): (Double, Double, Double) = switch Int(sector) {
    case 0: (chroma, second, 0)
    case 1: (second, chroma, 0)
    case 2: (0, chroma, second)
    case 3: (0, second, chroma)
    case 4: (second, 0, chroma)
    default: (chroma, 0, second)
    }
    return PetalTint(red: r + base, green: g + base, blue: b + base)
  }
}

nonisolated private func lanternFraction(_ x: Double) -> Double { x - floor(x) }

// MARK: - Petal geometry

/// The flower's petal outlines in its own unit space (outer reach 1, centred on the
/// origin), one per tint, first petal pointing up.
enum LanternFlowerShape {
  static func petals(count: Int, ruffle: Double) -> [Path] {
    let halfWidth = 0.5 * sin(Double.pi / Double(count) * 1.3)
    return (0..<count).map { index in
      petal(
        halfWidth: halfWidth,
        roundness: 0.45 + 0.4 * ruffle,
        ruffle: ruffle,
        phase: Double(index),
        angle: Double(index) * 2 * .pi / Double(count) - .pi / 2
      )
    }
  }

  /// A petal along +x from 0.05 to 1, its edge pushed in and out toward the tip
  /// when ruffled, smoothed, then turned to `angle`.
  private static func petal(halfWidth: Double, roundness: Double, ruffle: Double, phase: Double, angle: Double) -> Path {
    let samples = 40
    let base = 0.05
    let waves = 6.0
    func profile(_ u: Double) -> Double {
      pow(max(sin(.pi * pow(min(max(u, 0), 1), 1.25)), 0), roundness)
    }

    var outline: [CGPoint] = []
    outline.reserveCapacity(samples)
    for index in 0..<samples {
      let s = 2 * Double.pi * Double(index) / Double(samples)
      let u = (1 - cos(s)) / 2
      let side: Double = s <= .pi ? 1 : -1
      outline.append(CGPoint(x: base + u * (1 - base), y: side * halfWidth * profile(u)))
    }

    let amplitude = ruffle * 0.028
    var shaped: [CGPoint] = []
    shaped.reserveCapacity(samples)
    for index in 0..<samples {
      let s = 2 * Double.pi * Double(index) / Double(samples)
      let u = (1 - cos(s)) / 2
      let previous = outline[(index - 1 + samples) % samples]
      let next = outline[(index + 1) % samples]
      let tx = next.x - previous.x
      let ty = next.y - previous.y
      let norm = max(sqrt(tx * tx + ty * ty), 0.000_001)
      let offset = amplitude * eegSmoothstep(0.3, 0.72, u)
        * (sin(waves * s + phase) + 0.35 * sin((waves * 2 + 1) * s + phase * 1.7))
      shaped.append(CGPoint(x: outline[index].x - ty / norm * offset, y: outline[index].y + tx / norm * offset))
    }

    func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
    var path = Path()
    path.move(to: mid(shaped[samples - 1], shaped[0]))
    for index in 0..<samples {
      path.addQuadCurve(to: mid(shaped[index], shaped[(index + 1) % samples]), control: shaped[index])
    }
    path.closeSubpath()
    return path.applying(CGAffineTransform(rotationAngle: angle))
  }
}

#endif
