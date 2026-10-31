#if DEBUG
import SwiftUI
import UIKit

// PROTOTYPE — throwaway, DEBUG only. Variant B, Mindful Flower Art.
// Mine: each minute of the sit opens one ring of petals, centre outwards,
// like tree rings, so the finished flower is a record of the sit.
// - Ring hue: the alpha / theta balance (alpha-led green, theta-led violet),
//   pulled towards rose when beta (a busy mind) is high. Pastel.
// - Petal edges: calm makes smooth, full petals; low calm ruffles them.
// - Petal length and fullness: relative alpha.
// - Petal count per ring: the rhythm the minute opened in (its first 8 s),
//   more, narrower petals when beta leads, fewer, broader ones when theta does.
// - Each petal is its own few-second slice of the minute, so a ring sweeps
//   open like a clock hand and finished rings are drawn by the same rule.
// - Blinks drop pollen, jaw clenches leave a crease, the centre glows at the
//   heart rate.
// Together: a Yi Peng night. Each of 36 sitters gives one petal to a shared
// lotus mandala; the centre blooms with the group's mean calm. Exhibition
// turns everyone's flower into a khom loi lantern rising into the sky.

// MARK: - Night palette (prototype-local source of truth)

private struct NightColorToken {
  let red: Double
  let green: Double
  let blue: Double
  var color: Color { Color(red: red, green: green, blue: blue) }
}

/// The Yi Peng night. The DEEP palette has no dark sky or lantern light.
private enum NightPalette {
  static let nightIndigo  = NightColorToken(red: 0.067, green: 0.071, blue: 0.180)
  static let duskPlum     = NightColorToken(red: 0.176, green: 0.106, blue: 0.247)
  static let emberHaze    = NightColorToken(red: 0.471, green: 0.239, blue: 0.282)
  static let ridgeShadow  = NightColorToken(red: 0.090, green: 0.063, blue: 0.137)
  static let lanternGold  = NightColorToken(red: 1.000, green: 0.792, blue: 0.459)
  static let lanternFlame = NightColorToken(red: 1.000, green: 0.553, blue: 0.267)
  static let starlight    = NightColorToken(red: 1.000, green: 0.965, blue: 0.902)
}

private extension ShapeStyle where Self == Color {
  static var nightIndigo: Color { NightPalette.nightIndigo.color }
  static var duskPlum: Color { NightPalette.duskPlum.color }
  static var emberHaze: Color { NightPalette.emberHaze.color }
  static var ridgeShadow: Color { NightPalette.ridgeShadow.color }
  static var lanternGold: Color { NightPalette.lanternGold.color }
  static var lanternFlame: Color { NightPalette.lanternFlame.color }
  static var starlight: Color { NightPalette.starlight.color }
}

// MARK: - Small maths

private func flowerSmooth(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
  let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
  return t * t * (3 - 2 * t)
}

private func fraction(_ x: Double) -> Double { x - floor(x) }

private func lerpHue(_ from: Double, _ to: Double, _ amount: Double) -> Double {
  var delta = to - from
  if delta > 0.5 { delta -= 1 } else if delta < -0.5 { delta += 1 }
  return fraction(from + delta * amount)
}

private extension CGPoint {
  static func polar(_ radius: Double, _ angle: Double) -> CGPoint {
    CGPoint(x: radius * cos(angle), y: radius * sin(angle))
  }
}

private func disc(_ center: CGPoint, _ radius: Double) -> Path {
  Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

// MARK: - Petal ink (the α / θ / β → colour rule)

/// The band tints as hue / saturation / brightness, read once.
private enum BandHue {
  static let alpha = hue(of: EEGBand.alpha.tint)
  static let theta = hue(of: EEGBand.theta.tint)
  static let beta = hue(of: EEGBand.beta.tint)

  private static func hue(of color: Color) -> Double {
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    return Double(hue)
  }
}

/// One petal's colour family: deep at the hidden base, the body where the
/// petal shows, a pale tip.
private struct PetalInk {
  var hue: Double
  var saturation: Double
  var brightness: Double

  var body: Color { Color(hue: hue, saturation: saturation, brightness: brightness) }
  var deep: Color { Color(hue: hue, saturation: min(saturation + 0.16, 1), brightness: brightness - 0.13) }
  var light: Color { Color(hue: hue, saturation: saturation * 0.35, brightness: min(brightness + 0.03, 1)) }

  /// 0 alpha-led … 1 theta-led.
  static func thetaLean(_ powers: BandPowers) -> Double {
    flowerSmooth(0.28, 0.56, powers.theta / max(powers.alpha + powers.theta, 0.001))
  }

  /// 0 quiet … 1 beta-led (a busy mind).
  static func busy(_ powers: BandPowers) -> Double {
    flowerSmooth(0.10, 0.46, powers.beta / max(powers.alpha + powers.theta + powers.beta, 0.001))
  }

  static func from(_ powers: BandPowers, shift: Double = 0) -> PetalInk {
    let lean = thetaLean(powers)
    let busy = busy(powers)
    var hue = lerpHue(BandHue.alpha, BandHue.theta, lean)
    hue = lerpHue(hue, BandHue.beta, busy * 0.8)
    return PetalInk(
      hue: fraction(hue + shift),
      saturation: 0.27 + 0.05 * (1 - busy),
      brightness: 0.96
    )
  }

  func mixed(with other: PetalInk, _ amount: Double) -> PetalInk {
    PetalInk(
      hue: lerpHue(hue, other.hue, amount),
      saturation: saturation + (other.saturation - saturation) * amount,
      brightness: brightness + (other.brightness - brightness) * amount
    )
  }
}

// MARK: - Petal geometry

private struct PetalSpec {
  var base: Double = 0.03
  /// Tip radius, in flower units (the flower's outer reach is ~1).
  var length: Double
  var halfWidth: Double
  /// Exponent on the width profile: < 0.5 round and full, → 1 pointed.
  var roundness: Double
  /// 0 smooth … 1 ruffled.
  var ruffle: Double
  var waves: Int
  var phase: Double
  var crease = false
  /// A carnation edge instead of free waves: small regular scallops, mirrored
  /// about the petal's axis, sized to the petal's width so the silhouette
  /// never changes. For long, narrow petals (the group mandala).
  var scalloped = false

  static func profile(_ u: Double, roundness: Double) -> Double {
    pow(max(sin(.pi * pow(min(max(u, 0), 1), 1.25)), 0), roundness)
  }
}

/// A petal outline along +x, smoothed, then turned to `angle`. Also returns a
/// fold line when the petal carries a crease.
private func petalPaths(_ spec: PetalSpec, angle: Double, samples: Int = 88) -> (Path, Path?) {
  var outline: [CGPoint] = []
  outline.reserveCapacity(samples)
  for index in 0..<samples {
    let s = 2 * Double.pi * Double(index) / Double(samples)
    let u = (1 - cos(s)) / 2
    let side: Double = s <= .pi ? 1 : -1
    let width = spec.halfWidth * PetalSpec.profile(u, roundness: spec.roundness)
    outline.append(CGPoint(x: spec.base + u * (spec.length - spec.base), y: side * width))
  }

  // Ruffle: push the edge in and out along its normal, strongest at the tip.
  var shaped: [CGPoint] = []
  shaped.reserveCapacity(samples)
  let amplitude = spec.ruffle * (0.012 + 0.016 * spec.length)
  for index in 0..<samples {
    let s = 2 * Double.pi * Double(index) / Double(samples)
    let u = (1 - cos(s)) / 2
    let previous = outline[(index - 1 + samples) % samples]
    let next = outline[(index + 1) % samples]
    let tx = next.x - previous.x
    let ty = next.y - previous.y
    let norm = max(sqrt(tx * tx + ty * ty), 0.000_001)
    let nx = -ty / norm
    let ny = tx / norm
    var offset: Double
    if spec.scalloped {
      // A function of u alone, so both edges mirror; |sin| gives round
      // scallops with soft notches between them.
      let scallop = abs(sin(Double(spec.waves) * .pi * u)) - 0.55
      offset = spec.ruffle * spec.halfWidth * 0.09 * flowerSmooth(0.5, 0.86, u) * scallop
    } else {
      offset = amplitude * flowerSmooth(0.3, 0.72, u) * (
        sin(Double(spec.waves) * s + spec.phase)
          + 0.35 * sin(Double(spec.waves * 2 + 1) * s + spec.phase * 1.7)
      )
    }
    if spec.crease, s < .pi {
      offset -= spec.halfWidth * 0.32 * exp(-pow((u - 0.82) / 0.05, 2))
    }
    shaped.append(CGPoint(x: outline[index].x + nx * offset, y: outline[index].y + ny * offset))
  }

  let turn = CGAffineTransform(rotationAngle: angle)
  var path = Path()
  func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
  path.move(to: mid(shaped[samples - 1], shaped[0]))
  for index in 0..<samples {
    path.addQuadCurve(to: mid(shaped[index], shaped[(index + 1) % samples]), control: shaped[index])
  }
  path.closeSubpath()

  var fold: Path?
  if spec.crease {
    let along = spec.length - spec.base
    let width = spec.halfWidth * PetalSpec.profile(0.82, roundness: spec.roundness)
    var line = Path()
    line.move(to: CGPoint(x: spec.base + along * 0.82, y: width * 0.66))
    line.addQuadCurve(
      to: CGPoint(x: spec.base + along * 0.64, y: width * 0.08),
      control: CGPoint(x: spec.base + along * 0.76, y: width * 0.22)
    )
    fold = line.applying(turn)
  }
  return (path.applying(turn), fold)
}

/// Grows a petal out of the ring: short and narrow, curled, then unfurled.
private func unfurl(angle: Double, growth: Double) -> CGAffineTransform {
  let along = 0.3 + 0.7 * growth
  let across = 0.35 + 0.65 * growth
  let curl = (1 - growth) * 0.45
  return CGAffineTransform(rotationAngle: -angle)
    .concatenating(CGAffineTransform(scaleX: along, y: across))
    .concatenating(CGAffineTransform(rotationAngle: angle + curl))
}

// MARK: - The personal flower, precomputed once per sit

private struct FlowerPetal {
  let angle: Double
  let path: Path
  let fold: Path?
  let tip: Double
  /// Where this petal starts to show (the ring inside it ends), 0…1 of its length.
  let shows: Double
  let ink: PetalInk
  let appearsAt: Double
  let growFor: Double
}

private struct FlowerRing {
  let index: Int
  let start: Double
  let innerTip: Double
  let tip: Double
  let petals: [FlowerPetal]
}

private struct PollenGrain {
  let point: CGPoint
  let radius: Double
  let at: Double
  let tint: Double
}

private struct Stamen {
  let point: CGPoint
  let radius: Double
  let depth: Double
}

private struct FlowerModel {
  static let centreRadius = 0.105
  static let firstTip = 0.135

  let rings: [FlowerRing]
  let pollen: [PollenGrain]
  let stamens: [Stamen]
  let halo: PetalInk
  let finalOuter: Double

  init(recording: EEGSessionRecording) {
    let frames = recording.frames
    let rate = recording.frameRate

    func mean(_ from: Double, _ to: Double) -> (powers: BandPowers, calm: Double) {
      let lower = min(max(Int(from * rate), 0), frames.count - 1)
      let upper = min(max(Int(to * rate), lower + 1), frames.count)
      var powers = BandPowers.zero
      var calm = 0.0
      for index in lower..<upper {
        powers = powers + frames[index].relative
        calm += frames[index].calm
      }
      let count = Double(upper - lower)
      return (powers / count, calm / count)
    }

    var random = SeededRandom(seed: recording.profile.seed &+ 404)
    var rings: [FlowerRing] = []
    var pollen: [PollenGrain] = []
    var innerTip = Self.firstTip
    let events = recording.events

    for k in 0..<10 {
      let start = Double(k) * 60
      let opening = mean(start, start + 8).powers
      let busy = PetalInk.busy(opening)
      let lean = PetalInk.thetaLean(opening)
      let count = min(max(Int(((5 + Double(k) * 1.55) * (0.82 + 0.8 * busy - 0.22 * lean)).rounded()), 5), 30)
      let spacing = 2 * Double.pi / Double(count)
      let rotation = Double(k) * 2.399_963 + random.unit() * 0.6
      let slot = 52.0 / Double(count)

      // Which petal a moment of this minute belongs to.
      func petalIndex(at time: Double) -> Int {
        min(max(Int((time - start - 8) / slot), 0), count - 1)
      }
      let clenches = Set(
        events.filter { $0.kind == .jawClench && $0.time >= start && $0.time < start + 60 }
          .map { petalIndex(at: $0.time) }
      )

      var petals: [FlowerPetal] = []
      for j in 0..<count {
        let slotStart = start + 8 + Double(j) * slot
        let here = mean(slotStart - 4, slotStart + slot + 4)
        let soFar = mean(start, slotStart + slot)
        let alpha = here.powers.alpha * 0.6 + soFar.powers.alpha * 0.4
        let alphaN = flowerSmooth(0.13, 0.42, alpha)
        let calm = here.calm * 0.6 + soFar.calm * 0.4
        let ruffle = 1 - flowerSmooth(0.18, 0.8, calm)

        let tip = innerTip + (0.05 + 0.036 * alphaN) * (0.9 + 0.2 * random.unit())
        let angle = rotation + Double(j) * spacing + (random.unit() - 0.5) * 0.22 * spacing
        let roundness = 0.42 + 0.42 * ruffle
        let base = 0.03
        let shows = (innerTip - base) / (tip - base)
        // Wide enough at the ring's edge to overlap its neighbours, so the
        // tips read as layered scallops.
        let halfAngle = spacing / 2 * (1.05 + 0.55 * alphaN)
        let halfWidth = min(
          innerTip * tan(min(halfAngle, 1.1)) / max(PetalSpec.profile(shows, roundness: roundness), 0.2),
          tip * 0.5
        )
        let spec = PetalSpec(
          base: base,
          length: tip,
          halfWidth: halfWidth,
          roundness: roundness,
          ruffle: ruffle,
          waves: 6 + Int(ruffle * 6),
          phase: random.unit() * 6.28,
          crease: clenches.contains(j)
        )
        let (path, fold) = petalPaths(spec, angle: angle)
        let ink = PetalInk.from(here.powers).mixed(with: PetalInk.from(soFar.powers), 0.55)
        petals.append(FlowerPetal(
          angle: angle,
          path: path,
          fold: fold,
          tip: tip,
          shows: shows,
          ink: ink,
          appearsAt: slotStart,
          growFor: max(slot * 2.2, 7)
        ))
      }

      let tip = petals.map(\.tip).reduce(0, +) / Double(petals.count)
      for blink in events where blink.kind == .blink && blink.time >= start && blink.time < start + 60 {
        let petal = petals[petalIndex(at: blink.time)]
        let angle = petal.angle + (random.unit() - 0.5) * spacing * 0.7
        let radius = innerTip + (petal.tip - innerTip) * (0.3 + 0.5 * random.unit())
        pollen.append(PollenGrain(
          point: .polar(radius, angle),
          radius: 0.006 + 0.004 * random.unit(),
          at: max(blink.time, petal.appearsAt + petal.growFor * 0.6),
          tint: random.unit()
        ))
      }

      rings.append(FlowerRing(index: k, start: start, innerTip: innerTip, tip: tip, petals: petals))
      innerTip = tip
    }

    var stamens: [Stamen] = []
    let stamenCount = 64
    for index in 0..<stamenCount {
      let depth = sqrt((Double(index) + 0.5) / Double(stamenCount))
      stamens.append(Stamen(
        point: .polar(Self.centreRadius * 0.86 * depth, Double(index) * 2.399_963),
        radius: Self.centreRadius * (0.07 + 0.05 * depth),
        depth: depth
      ))
    }

    let whole = mean(0, EEGSessionRecording.duration).powers
    self.rings = rings
    self.pollen = pollen
    self.stamens = stamens
    self.halo = PetalInk.from(whole)
    self.finalOuter = rings.map { $0.petals.map(\.tip).max() ?? $0.tip }.max() ?? 1
  }

  /// The flower's reach at a session time, for the live camera.
  func outerRadius(at time: Double) -> Double {
    var outer = Self.firstTip
    for ring in rings {
      let progress = flowerSmooth(ring.start + 6, ring.start + 62, time)
      guard progress > 0 else { break }
      outer = ring.innerTip + (ring.tip - ring.innerTip) * progress
    }
    return outer
  }
}

// MARK: - Painting the personal flower

private enum FlowerPainter {
  static func paint(
    _ context: inout GraphicsContext,
    size: CGSize,
    model: FlowerModel,
    time: Double,
    beat: Double,
    live: EEGFrame?
  ) {
    let reach = live == nil ? model.finalOuter : model.outerRadius(at: time) * 1.04
    let zoom = min(3.2, 0.86 / max(reach, 0.2))
    let scale = min(size.width, size.height) / 2 * zoom
    // Small dots go through an unscaled context, in points, so they stay round.
    var dots = context
    dots.translateBy(x: size.width / 2, y: size.height / 2)
    var c = dots
    c.scaleBy(x: scale, y: scale)
    let pixel = 1 / scale
    func onScreen(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x * scale, y: point.y * scale) }

    // A coloured halo, never white, so the flower sits in light on the
    // pale atmosphere instead of in a grey smudge.
    let haloRadius = 1 / zoom
    c.fill(disc(.zero, haloRadius), with: .radialGradient(
      Gradient(stops: [
        .init(color: model.halo.body.opacity(0.42), location: 0),
        .init(color: model.halo.body.opacity(0.26), location: 0.6),
        .init(color: model.halo.body.opacity(0), location: 1)
      ]),
      center: .zero, startRadius: 0, endRadius: haloRadius
    ))

    let liveInk = live.map { PetalInk.from($0.relative) }
    let visible = model.rings.filter { $0.start + 8 <= time }
    for ring in visible.reversed() {
      // This ring's soft shadow onto the ring behind it.
      if ring.index < (visible.last?.index ?? 0) {
        let outer = ring.tip + 0.05
        c.fill(disc(.zero, outer), with: .radialGradient(
          Gradient(stops: [
            .init(color: Color.deepPlum.opacity(0), location: (ring.tip - 0.06) / outer),
            .init(color: Color.deepPlum.opacity(0.11), location: ring.tip / outer),
            .init(color: Color.deepPlum.opacity(0), location: 1)
          ]),
          center: .zero, startRadius: 0, endRadius: outer
        ))
      }
      for petal in ring.petals where petal.appearsAt <= time {
        let growth = flowerSmooth(petal.appearsAt, petal.appearsAt + petal.growFor, time)
        var ink = petal.ink
        var path = petal.path
        var fold = petal.fold
        var tipReach = petal.tip
        var layer = c
        if growth < 1 {
          let transform = unfurl(angle: petal.angle, growth: growth)
          path = path.applying(transform)
          fold = fold?.applying(transform)
          tipReach *= 0.3 + 0.7 * growth
          layer.opacity = min(1, growth * 3)
          // The opening petal wears the live reading, settling into its own.
          if let liveInk { ink = liveInk.mixed(with: ink, growth) }
        }
        paintPetal(&layer, path: path, fold: fold, ink: ink, angle: petal.angle, tip: tipReach, shows: petal.shows, pixel: pixel)
      }
    }

    for grain in model.pollen where grain.at <= time {
      let pop = flowerSmooth(grain.at, grain.at + 3, time)
      let radius = grain.radius * 260 * (0.4 + 0.6 * pop)
      let point = onScreen(grain.point)
      let gold = EEGBand.gamma.tint.mix(with: .peachCloud, by: 0.15 + 0.35 * grain.tint)
      dots.fill(disc(point, radius * 2), with: .color(gold.opacity(0.25 * pop)))
      dots.fill(disc(point, radius), with: .color(gold.mix(with: .duskRose, by: 0.18).opacity(pop)))
      dots.fill(
        disc(CGPoint(x: point.x - radius * 0.3, y: point.y - radius * 0.3), radius * 0.4),
        with: .color(Color.moonCream.opacity(0.85 * pop))
      )
    }

    // During the sit the centre starts as a small bud and widens.
    let centre = live == nil ? 1 : 0.62 + 0.38 * flowerSmooth(0, 300, time)
    paintCentre(&c, dots: &dots, scale: scale, model: model, beat: beat, size: centre)
  }

  static func paintPetal(
    _ c: inout GraphicsContext,
    path: Path,
    fold: Path?,
    ink: PetalInk,
    angle: Double,
    tip: Double,
    shows: Double,
    pixel: Double
  ) {
    let shownFrom = min(max(shows, 0.05), 0.95)
    let gradient = Gradient(stops: [
      .init(color: ink.deep, location: max(shownFrom - 0.18, 0)),
      .init(color: ink.body, location: shownFrom + (1 - shownFrom) * 0.3),
      .init(color: ink.light, location: 1)
    ])
    c.fill(path, with: .linearGradient(gradient, startPoint: .zero, endPoint: .polar(tip, angle)))
    c.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 1.1 * pixel)
    if let fold {
      c.stroke(fold, with: .color(ink.deep.opacity(0.6)), style: StrokeStyle(lineWidth: 1.3 * pixel, lineCap: .round))
    }
  }

  static func paintCentre(
    _ c: inout GraphicsContext,
    dots: inout GraphicsContext,
    scale: Double,
    model: FlowerModel,
    beat: Double,
    size: Double
  ) {
    let radius = FlowerModel.centreRadius * size
    let gold = EEGBand.gamma.tint
    let glow = radius * (2.0 + 0.45 * beat)
    c.fill(disc(.zero, glow), with: .radialGradient(
      Gradient(stops: [
        .init(color: gold.mix(with: .peachCloud, by: 0.3).opacity(0.55 + 0.25 * beat), location: 0),
        .init(color: Color.peachCloud.opacity(0.35 + 0.15 * beat), location: 0.5),
        .init(color: Color.blushPowder.opacity(0), location: 1)
      ]),
      center: .zero, startRadius: 0, endRadius: glow
    ))
    c.fill(disc(.zero, radius), with: .radialGradient(
      Gradient(colors: [
        gold.mix(with: .moonCream, by: 0.55),
        gold.mix(with: .peachCloud, by: 0.2),
        gold.mix(with: .duskRose, by: 0.28)
      ]),
      center: .zero, startRadius: 0, endRadius: radius
    ))
    let swell = (1 + 0.05 * beat) * size * scale
    for stamen in model.stamens {
      let point = CGPoint(x: stamen.point.x * swell, y: stamen.point.y * swell)
      let dot = stamen.radius * swell
      let tone = gold.mix(with: .duskRose, by: 0.15 + 0.4 * stamen.depth)
      dots.fill(disc(point, dot), with: .color(tone))
      dots.fill(
        disc(CGPoint(x: point.x - dot * 0.3, y: point.y - dot * 0.3), dot * 0.45),
        with: .color(Color.moonCream.opacity(0.7))
      )
    }
  }
}

/// Integrates heart rate into a beat phase, so the centre's pulse follows a
/// changing rate without jumping.
@MainActor
private final class BeatClock {
  private var phase = 0.0
  private var lastWall: Double?

  func beat(at wall: Double, heartRate: Double) -> Double {
    if let lastWall { phase += min(max(wall - lastWall, 0), 0.1) * heartRate / 60 }
    lastWall = wall
    // A soft swell once per beat, not a flash.
    return pow(0.5 + 0.5 * cos(2 * .pi * fraction(phase)), 2.5)
  }
}

// MARK: - The group (Yi Peng)

private struct MemberLook {
  var ink: PetalInk
  var ruffle: Double
  var alphaN: Double
  var calm: Double

  static func from(_ powers: BandPowers, calm: Double, shift: Double) -> MemberLook {
    var ink = PetalInk.from(powers, shift: shift * 0.05)
    ink.saturation += 0.24
    ink.brightness = 0.92
    return MemberLook(
      ink: ink,
      ruffle: 1 - flowerSmooth(0.18, 0.8, calm),
      alphaN: flowerSmooth(0.13, 0.42, powers.alpha),
      calm: calm
    )
  }
}

private struct GroupMember {
  let participant: EEGParticipant
  let angle: Double
  let inner: Bool
  let finalLook: MemberLook
  /// Their own small flower, unit radius, for the lantern's face.
  let rosette: [Path]
  let rosetteInks: [PetalInk]
  // Exhibition lantern.
  let depth: Double
  let column: Double
  let period: Double
  let offset: Double
}

private struct Star {
  let x: Double
  let y: Double
  let radius: Double
  let phase: Double
  let speed: Double
}

private struct DriftLantern {
  let x: Double
  let radius: Double
  let period: Double
  let offset: Double
}

private struct GroupModel {
  static let slots = 18
  /// The viewer's own seat: slot 0, the top of the mandala.
  static let youID = 0

  let members: [GroupMember]
  let stars: [Star]
  let drifters: [DriftLantern]

  /// The group with the viewer's own sit in seat 0, so they can find
  /// themselves among everyone else.
  init(you: EEGSessionRecording) {
    var participants = EEGGroupSession.participants(count: 36)
    participants[Self.youID] = EEGParticipant(
      id: Self.youID, name: "You", joinedAt: 0, recording: you, hueShift: 0
    )
    var random = SeededRandom(seed: 8_812)
    let spacing = 2 * Double.pi / Double(Self.slots)
    members = participants.map { person -> GroupMember in
      let frames = person.recording.frames
      let whole = frames.reduce(BandPowers.zero) { $0 + $1.relative } / Double(frames.count)
      let look = MemberLook.from(whole, calm: person.recording.summary.averageCalm, shift: person.hueShift)
      let inner = person.id % 2 == 1
      let slot = Double(person.id / 2) + (inner ? 0.5 : 0)

      // Their rosette: a ring of the minute colours of their own sit.
      let minutes = person.recording.minutes
      let count = 6 + Int(PetalInk.busy(whole) * 4)
      var paths: [Path] = []
      var inks: [PetalInk] = []
      for j in 0..<count {
        let minute = minutes[(j * minutes.count) / count]
        let spec = PetalSpec(
          base: 0.05,
          length: 1,
          halfWidth: 0.5 * sin(Double.pi / Double(count) * 1.3),
          roundness: 0.45 + 0.4 * look.ruffle,
          ruffle: look.ruffle,
          waves: 6,
          phase: Double(j)
        )
        paths.append(petalPaths(spec, angle: Double(j) * 2 * .pi / Double(count) - .pi / 2, samples: 40).0)
        var ink = PetalInk.from(minute.relative, shift: person.hueShift * 0.05)
        ink.saturation += 0.12
        inks.append(ink)
      }

      return GroupMember(
        participant: person,
        angle: slot * spacing - .pi / 2,
        inner: inner,
        finalLook: look,
        rosette: paths,
        rosetteInks: inks,
        depth: 0.25 + 0.75 * random.unit(),
        column: (Double(person.id) + random.unit() * 0.8) / Double(participants.count),
        period: 46 + random.unit() * 26,
        offset: random.unit()
      )
    }
    stars = (0..<170).map { _ in
      Star(
        x: random.unit(),
        y: pow(random.unit(), 1.4),
        radius: 0.35 + pow(random.unit(), 3) * 1.2,
        phase: random.unit() * 6.28,
        speed: 0.6 + random.unit() * 1.8
      )
    }
    drifters = (0..<46).map { _ in
      DriftLantern(x: random.unit(), radius: 0.8 + random.unit() * 1.6, period: 60 + random.unit() * 60, offset: random.unit())
    }
  }

  func look(of member: GroupMember, at time: Double?) -> MemberLook? {
    guard let time else { return member.finalLook }
    guard let frame = member.participant.frame(at: time) else { return nil }
    return MemberLook.from(frame.relative, calm: frame.calm, shift: member.participant.hueShift)
  }
}

@MainActor
private enum FlowerCache {
  static var flowers: [UInt64: FlowerModel] = [:]
  static var groups: [UInt64: GroupModel] = [:]

  static func group(for recording: EEGSessionRecording) -> GroupModel {
    if let group = groups[recording.profile.seed] { return group }
    let group = GroupModel(you: recording)
    groups[recording.profile.seed] = group
    return group
  }

  static func flower(for recording: EEGSessionRecording) -> FlowerModel {
    if let flower = flowers[recording.profile.seed] { return flower }
    let flower = FlowerModel(recording: recording)
    flowers[recording.profile.seed] = flower
    return flower
  }
}

// MARK: - Painting the night

private enum NightPainter {
  static func sky(_ c: inout GraphicsContext, size: CGSize, wall: Double, stars: [Star], horizon: Double) {
    let rect = CGRect(origin: .zero, size: size)
    c.fill(Path(rect), with: .linearGradient(
      Gradient(stops: [
        .init(color: .nightIndigo, location: 0),
        .init(color: .duskPlum, location: 0.62),
        .init(color: .emberHaze, location: 1)
      ]),
      startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * horizon)
    ))
    if horizon < 1 {
      c.fill(Path(CGRect(x: 0, y: size.height * horizon, width: size.width, height: size.height)), with: .color(.emberHaze))
    }
    var glow = c
    glow.blendMode = .plusLighter
    for star in stars {
      let twinkle = 0.45 + 0.55 * (0.5 + 0.5 * sin(wall * star.speed + star.phase))
      let fade = 1 - flowerSmooth(0.55, 0.9, star.y)
      let point = CGPoint(x: star.x * size.width, y: star.y * size.height * horizon)
      glow.fill(disc(point, star.radius), with: .color(Color.starlight.opacity(0.8 * twinkle * fade)))
    }
  }

  static func lanternGlow(_ c: inout GraphicsContext, at point: CGPoint, radius: Double, strength: Double) {
    c.fill(disc(point, radius), with: .radialGradient(
      Gradient(stops: [
        .init(color: Color.lanternGold.opacity(0.55 * strength), location: 0),
        .init(color: Color.lanternFlame.opacity(0.18 * strength), location: 0.4),
        .init(color: Color.lanternFlame.opacity(0), location: 1)
      ]),
      center: point, startRadius: 0, endRadius: radius
    ))
  }

  static func drifters(_ c: inout GraphicsContext, size: CGSize, wall: Double, lanterns: [DriftLantern], floor: Double) {
    var glow = c
    glow.blendMode = .plusLighter
    for lantern in lanterns {
      let rise = fraction(wall / lantern.period + lantern.offset)
      let fade = flowerSmooth(0, 0.1, rise) * (1 - flowerSmooth(0.7, 1, rise))
      let point = CGPoint(
        x: lantern.x * size.width + 6 * sin(wall * 0.3 + lantern.offset * 9),
        y: size.height * floor * (1 - rise)
      )
      lanternGlow(&glow, at: point, radius: lantern.radius * 5, strength: fade * 0.7)
      glow.fill(disc(point, lantern.radius), with: .color(Color.lanternGold.opacity(fade)))
    }
  }
}

// MARK: - Root

enum EEGFlowerTab: String, CaseIterable, Identifiable {
  case mine, together

  var id: String { rawValue }
  var label: String {
    switch self {
    case .mine: "Mine"
    case .together: "Together"
    }
  }
}

/// Survives the host's per-stage identity reset, so flipping Live / After
/// keeps the tab. `-prototype.eegArt.flowerTab together` and
/// `-prototype.eegArt.flowerExhibition YES` boot straight in.
@MainActor
private enum FlowerMemory {
  static var tab = EEGFlowerTab(rawValue: UserDefaults.standard.string(forKey: "prototype.eegArt.flowerTab") ?? "") ?? .mine
  static var exhibition = UserDefaults.standard.bool(forKey: "prototype.eegArt.flowerExhibition")
}

struct EEGFlowerView: View {
  let player: EEGSessionPlayer
  let stage: EEGArtStage
  @State private var tab: EEGFlowerTab
  @State private var showsExhibition: Bool

  init(player: EEGSessionPlayer, stage: EEGArtStage, tab: EEGFlowerTab? = nil, exhibition: Bool? = nil) {
    self.player = player
    self.stage = stage
    _tab = State(initialValue: tab ?? FlowerMemory.tab)
    _showsExhibition = State(initialValue: exhibition ?? FlowerMemory.exhibition)
  }

  var body: some View {
    ZStack(alignment: .top) {
      switch tab {
      case .mine:
        MineFlowerScreen(player: player, stage: stage)
          .transition(.opacity)
      case .together:
        TogetherScreen(player: player, stage: stage)
          .transition(.opacity)
      }

      HStack {
        EEGFlowerTabs(tab: $tab, night: tab == .together)
        Spacer(minLength: 0)
        if tab == .together {
          Button {
            withAnimation(.hush) { showsExhibition = true }
          } label: {
            Label("Exhibition", systemImage: "sparkles")
              .font(DeepType.body.weight(.medium))
              .foregroundStyle(.starlight)
              .padding(.horizontal, 16)
              .frame(height: 40)
              .background(Color.white.opacity(0.1), in: Capsule())
          }
          .transition(.opacity)
          .accessibilityIdentifier("flower.exhibition")
        }
      }
      .padding(.horizontal, .edge)
      .padding(.top, 6)

      if showsExhibition {
        ExhibitionScreen(player: player, stage: stage) {
          withAnimation(.hush) { showsExhibition = false }
        }
        .transition(.opacity)
        .zIndex(2)
      }
    }
    .animation(.exhale, value: tab)
    .onChange(of: tab) { FlowerMemory.tab = tab }
    .onChange(of: showsExhibition) { FlowerMemory.exhibition = showsExhibition }
  }
}

private struct EEGFlowerTabs: View {
  @Binding var tab: EEGFlowerTab
  let night: Bool
  @Namespace private var pill

  var body: some View {
    HStack(spacing: 2) {
      ForEach(EEGFlowerTab.allCases) { option in
        Button {
          withAnimation(.settle) { tab = option }
        } label: {
          Text(option.label)
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(textColor(selected: option == tab))
            .padding(.horizontal, 18)
            .frame(height: 36)
            .background {
              if option == tab {
                Capsule()
                  .fill(night ? Color.lanternGold.opacity(0.92) : Color.white.opacity(0.9))
                  .matchedGeometryEffect(id: "pill", in: pill)
              }
            }
        }
        .accessibilityIdentifier("flower.tab.\(option.rawValue)")
      }
    }
    .padding(2)
    .background {
      if night {
        Capsule().fill(Color.white.opacity(0.1))
      } else {
        Capsule().fill(.ultraThinMaterial).overlay(Capsule().fill(Color.white.opacity(0.3)))
      }
    }
  }

  private func textColor(selected: Bool) -> Color {
    if night { return selected ? .nightIndigo : Color.starlight.opacity(0.72) }
    return selected ? .deepPlum : .driftGrey
  }
}

// MARK: - Mine

private struct MineFlowerScreen: View {
  let player: EEGSessionPlayer
  let stage: EEGArtStage

  var body: some View {
    let model = FlowerCache.flower(for: player.recording)
    ZStack {
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()
      switch stage {
      case .live: MineLiveView(player: player, model: model)
      case .after: MineKeepsakeView(recording: player.recording, model: model)
      }
    }
  }
}

private struct MineLiveView: View {
  let player: EEGSessionPlayer
  let model: FlowerModel
  @State private var clock = BeatClock()

  var body: some View {
    let frame = player.current
    let ring = min(Int(player.sessionTime / 60), 9) + 1
    VStack(spacing: 0) {
      VStack(spacing: 6) {
        Text(player.isFinished ? "TEN RINGS, ONE SIT" : "RING \(ring) OF 10 IS OPENING")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
          .contentTransition(.numericText())
        Text(frame.phase.label)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .contentTransition(.opacity)
          .animation(.exhale, value: frame.phase)
      }
      .padding(.top, 70)

      TimelineView(.animation) { context in
        let time = player.sessionTime(at: context.date)
        let live = player.recording.frame(at: time)
        let beat = clock.beat(at: context.date.timeIntervalSinceReferenceDate, heartRate: live.heartRate)
        Canvas { graphics, size in
          FlowerPainter.paint(&graphics, size: size, model: model, time: time, beat: beat, live: live)
        }
      }
      .frame(maxWidth: .infinity)
      .aspectRatio(1, contentMode: .fit)
      .padding(.horizontal, 8)
      .padding(.top, 8)

      HStack(spacing: 40) {
        FlowerFact(value: "\(Int(frame.heartRate.rounded()))", label: "BPM")
        FlowerFact(value: "\(Int((frame.calm * 100).rounded()))", label: "CALM")
      }
      Text("Calm is DEEP's own index, from your alpha and beta.")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .padding(.top, 8)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, .edge)
  }
}

private struct FlowerFact: View {
  let value: String
  let label: String
  var night = false

  var body: some View {
    VStack(spacing: 2) {
      Text(value)
        .font(DeepType.bigNumber)
        .monospacedDigit()
        .foregroundStyle(night ? Color.starlight : Color.deepPlum)
        .contentTransition(.numericText())
      Text(label)
        .font(DeepType.micro)
        .tracking(.microTracking)
        .multilineTextAlignment(.center)
        .foregroundStyle(night ? Color.starlight.opacity(0.6) : Color.driftGrey)
    }
  }
}

private struct MineKeepsakeView: View {
  let recording: EEGSessionRecording
  let model: FlowerModel

  var body: some View {
    let summary = recording.summary
    let minutes = recording.minutes
    let peak = (minutes.max { $0.calm < $1.calm }?.index ?? 0) + 1
    let slower = Int((summary.heartRateStart - summary.heartRateEnd).rounded())
    VStack(spacing: 14) {
      VStack(spacing: 16) {
        Canvas { graphics, size in
          FlowerPainter.paint(&graphics, size: size, model: model, time: EEGSessionRecording.duration + 60, beat: 0.4, live: nil)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 300)

        VStack(spacing: 4) {
          Text(Date.now, format: .dateTime.day().month(.wide).year())
            .font(DeepType.micro)
            .tracking(.microTracking)
            .textCase(.uppercase)
            .foregroundStyle(.driftGrey)
          Text("Ten minutes, ten rings")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          Text("10 min · \(recording.person?.label ?? "Your sit")")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        }

        HStack(alignment: .top, spacing: 0) {
          FlowerFact(value: "\(peak)", label: "CALMEST\nMINUTE")
            .frame(maxWidth: .infinity)
          FlowerFact(value: "+\(summary.alphaRisePercent)%", label: "ALPHA\nRISE")
            .frame(maxWidth: .infinity)
          FlowerFact(value: slower > 0 ? "−\(slower)" : "\(abs(slower))", label: "HEART\nBPM")
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.vertical, 22)
      .padding(.horizontal, 16)
      .frostedCard()

      Text("Each ring is a minute. Colour from alpha and theta, smooth edges from calm, pollen from blinks.")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, .edge)
    .padding(.top, 62)
  }
}

// MARK: - Together

private struct TogetherScreen: View {
  let player: EEGSessionPlayer
  let stage: EEGArtStage
  @State private var selected: Int?

  private var group: GroupModel { FlowerCache.group(for: player.recording) }

  var body: some View {
    let group = self.group
    let time: Double? = stage == .live ? player.sessionTime : nil
    let joined = group.members.filter { time == nil || $0.participant.joinedAt <= time! }
    let looks = joined.compactMap { group.look(of: $0, at: time) }
    let groupCalm = looks.isEmpty ? 0 : looks.map(\.calm).reduce(0, +) / Double(looks.count)
    ZStack {
      TimelineView(.animation) { context in
        Canvas { graphics, size in
          NightPainter.sky(&graphics, size: size, wall: context.date.timeIntervalSinceReferenceDate, stars: group.stars, horizon: 1)
          NightPainter.drifters(&graphics, size: size, wall: context.date.timeIntervalSinceReferenceDate, lanterns: group.drifters, floor: 1.05)
        }
      }
      .ignoresSafeArea()

      VStack(spacing: 0) {
        VStack(spacing: 4) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(joined.count)")
              .font(DeepType.bigNumber)
              .monospacedDigit()
              .contentTransition(.numericText())
            Text(joined.count == 1 ? "person sitting" : (time == nil ? "people sat together" : "people sitting together"))
              .font(DeepType.revealTitle)
          }
          .foregroundStyle(.starlight)
          Text("Group calm \(Int((groupCalm * 100).rounded())) · the centre blooms when many are calm")
            .font(DeepType.caption)
            .foregroundStyle(Color.starlight.opacity(0.62))
        }
        .padding(.top, 70)
        .animation(.exhale, value: joined.count)

        GeometryReader { proxy in
          let side = min(proxy.size.width, proxy.size.height)
          TimelineView(.animation) { context in
            let now = stage == .live ? player.sessionTime(at: context.date) : nil
            Canvas { graphics, size in
              MandalaPainter.paint(
                &graphics, size: size, group: group, time: now,
                wall: context.date.timeIntervalSinceReferenceDate, selected: selected
              )
            }
          }
          .frame(width: side, height: side)
          .contentShape(Rectangle())
          .gesture(SpatialTapGesture().onEnded { value in
            select(at: value.location, side: side, time: time)
          })
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.top, 10)

        selectionChip(time: time)
          .frame(height: 64)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, .edge)
    }
  }

  @ViewBuilder
  private func selectionChip(time: Double?) -> some View {
    if let selected, let member = group.members.first(where: { $0.participant.id == selected }),
       let look = group.look(of: member, at: time) {
      let joinedAt = Int(member.participant.joinedAt)
      HStack(spacing: 12) {
        Circle()
          .fill(look.ink.body)
          .frame(width: 14, height: 14)
          .shadow(color: look.ink.body.opacity(0.8), radius: 6)
        VStack(alignment: .leading, spacing: 1) {
          Text(member.participant.name)
            .font(DeepType.revealTitle)
            .foregroundStyle(.starlight)
          Text("Joined at \(joinedAt / 60):\(String(format: "%02d", joinedAt % 60)) · calm \(Int((look.calm * 100).rounded()))")
            .font(DeepType.caption)
            .foregroundStyle(Color.starlight.opacity(0.62))
        }
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 10)
      .background(Color.white.opacity(0.08), in: Capsule())
      .transition(.opacity)
      .id(selected)
    } else {
      Text("Your petal is the one outlined at the top · tap any petal")
        .font(DeepType.caption)
        .foregroundStyle(Color.starlight.opacity(0.5))
        .transition(.opacity)
    }
  }

  private func select(at location: CGPoint, side: Double, time: Double?) {
    let centre = CGPoint(x: side / 2, y: side / 2)
    let unit = side / 2 * MandalaPainter.fit
    let point = CGPoint(x: (location.x - centre.x) / unit, y: (location.y - centre.y) / unit)
    let candidates = group.members.filter { time == nil || $0.participant.joinedAt <= time! }
    let best = candidates.min { a, b in
      distance(point, MandalaPainter.centroid(of: a)) < distance(point, MandalaPainter.centroid(of: b))
    }
    withAnimation(.exhale) {
      if let best, distance(point, MandalaPainter.centroid(of: best)) < 0.32, best.participant.id != selected {
        selected = best.participant.id
      } else {
        selected = nil
      }
    }
  }

  private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
    hypot(a.x - b.x, a.y - b.y)
  }
}

private enum MandalaPainter {
  /// Unit radius as a share of half the canvas.
  static let fit = 0.86

  static func spec(for member: GroupMember, look: MemberLook) -> PetalSpec {
    let halfAngle = Double.pi / Double(GroupModel.slots) * (0.95 + 0.4 * look.alphaN)
    let length = member.inner ? 0.5 + 0.1 * look.alphaN : 0.8 + 0.14 * look.alphaN
    return PetalSpec(
      base: 0.1,
      length: length,
      halfWidth: length * sin(halfAngle) * 0.66,
      roundness: 0.42 + 0.14 * look.ruffle,
      ruffle: look.ruffle,
      waves: 15,
      phase: 0,
      scalloped: true
    )
  }

  static func centroid(of member: GroupMember) -> CGPoint {
    .polar(member.inner ? 0.36 : 0.62, member.angle)
  }

  static func paint(
    _ context: inout GraphicsContext,
    size: CGSize,
    group: GroupModel,
    time: Double?,
    wall: Double,
    selected: Int?
  ) {
    let scale = min(size.width, size.height) / 2 * fit
    var c = context
    c.translateBy(x: size.width / 2, y: size.height / 2)
    c.scaleBy(x: scale, y: scale)
    let pixel = 1 / scale

    var looks: [Int: MemberLook] = [:]
    for member in group.members {
      if let look = group.look(of: member, at: time) { looks[member.participant.id] = look }
    }
    let calms = looks.values.map(\.calm)
    let groupCalm = calms.isEmpty ? 0 : calms.reduce(0, +) / Double(calms.count)
    let bloom = pow(flowerSmooth(0.2, 0.85, groupCalm), 1.4)

    var glow = c
    glow.blendMode = .plusLighter

    // The group's light, behind everything.
    let auraRadius = 0.7 + 0.45 * bloom
    glow.fill(disc(.zero, auraRadius), with: .radialGradient(
      Gradient(stops: [
        .init(color: Color.lanternGold.opacity(0.08 + 0.2 * bloom), location: 0),
        .init(color: Color.lanternFlame.opacity(0.04 + 0.08 * bloom), location: 0.45),
        .init(color: Color.lanternFlame.opacity(0), location: 1)
      ]),
      center: .zero, startRadius: 0, endRadius: auraRadius
    ))

    // Seats: one bead per person on the outer ring, lit once they join.
    for member in group.members {
      let point = CGPoint.polar(1.06, member.angle)
      let lit = looks[member.participant.id] != nil
      let radius = member.participant.id == GroupModel.youID ? 0.026 : member.inner ? 0.011 : 0.016
      if lit, member.participant.id == GroupModel.youID {
        NightPainter.lanternGlow(&glow, at: point, radius: radius * 4, strength: 1)
        c.fill(disc(point, radius), with: .color(.starlight))
      } else if lit {
        NightPainter.lanternGlow(&glow, at: point, radius: radius * 4, strength: 0.8)
        c.fill(disc(point, radius), with: .color(.lanternGold))
      } else {
        c.fill(disc(point, radius * 0.7), with: .color(Color.starlight.opacity(0.18)))
      }
    }

    // Outer petals first, then the inner lotus over them.
    let ordered = group.members.filter { !$0.inner } + group.members.filter(\.inner)
    for member in ordered {
      guard let look = looks[member.participant.id] else {
        let seed = CGPoint.polar(member.inner ? 0.3 : 0.5, member.angle)
        c.fill(disc(seed, 0.008), with: .color(Color.starlight.opacity(0.22)))
        continue
      }
      let growth = time.map { flowerSmooth(member.participant.joinedAt, member.participant.joinedAt + 10, $0) } ?? 1
      let spec = spec(for: member, look: look)
      var (path, _) = petalPaths(spec, angle: member.angle, samples: 300)
      var tip = spec.length
      if growth < 1 {
        path = path.applying(unfurl(angle: member.angle, growth: growth))
        tip *= 0.3 + 0.7 * growth
      }
      let isSelected = member.participant.id == selected
      let isYou = member.participant.id == GroupModel.youID
      let dim = selected == nil || isSelected ? 1.0 : 0.55

      let centroid = CGPoint.polar(tip * 0.6, member.angle)
      glow.fill(disc(centroid, tip * 0.45), with: .radialGradient(
        Gradient(colors: [look.ink.body.opacity(0.12 * growth * dim), look.ink.body.opacity(0)]),
        center: centroid, startRadius: 0, endRadius: tip * 0.45
      ))

      var layer = c
      layer.opacity = min(1, growth * 2.5) * (isSelected ? 1 : 0.94) * dim
      let ink = look.ink
      layer.fill(path, with: .linearGradient(
        Gradient(stops: [
          .init(color: ink.deep.mix(with: .duskPlum, by: 0.55), location: 0.15),
          .init(color: ink.body, location: 0.7),
          .init(color: ink.body.mix(with: .lanternGold, by: 0.45), location: 1)
        ]),
        startPoint: .zero, endPoint: .polar(tip, member.angle)
      ))
      layer.stroke(
        path,
        with: .color(Color.lanternGold.opacity(isSelected || isYou ? 0.95 : 0.4)),
        lineWidth: (isSelected ? 2.2 : isYou ? 1.8 : 0.9) * pixel
      )
    }

    // The centre blooms when many people are calm at once.
    let heart = 0.1 + 0.12 * bloom
    glow.fill(disc(.zero, heart * 2.2), with: .radialGradient(
      Gradient(stops: [
        .init(color: Color.starlight.opacity(0.15 + 0.45 * bloom), location: 0),
        .init(color: Color.lanternGold.opacity(0.25 + 0.4 * bloom), location: 0.3),
        .init(color: Color.lanternFlame.opacity(0), location: 1)
      ]),
      center: .zero, startRadius: 0, endRadius: heart * 2.2
    ))
    let centrePetals = 12
    for index in 0..<centrePetals {
      let angle = Double(index) / Double(centrePetals) * 2 * .pi + wall * 0.02
      let spec = PetalSpec(
        base: 0.01,
        length: 0.06 + 0.1 * bloom,
        halfWidth: (0.06 + 0.1 * bloom) * 0.28,
        roundness: 0.5,
        ruffle: 0,
        waves: 0,
        phase: 0
      )
      let (path, _) = petalPaths(spec, angle: angle, samples: 32)
      c.fill(path, with: .color(Color.lanternGold.opacity(0.3 + 0.5 * bloom)))
    }
    c.fill(disc(.zero, 0.035 + 0.015 * bloom), with: .color(Color.starlight.opacity(0.9)))
  }
}

// MARK: - Exhibition (the festival screen)

private struct ExhibitionScreen: View {
  let player: EEGSessionPlayer
  let stage: EEGArtStage
  let onClose: () -> Void

  private var group: GroupModel { FlowerCache.group(for: player.recording) }

  var body: some View {
    let group = self.group
    return GeometryReader { proxy in
      // A landscape festival screen, turned to fill the phone held sideways.
      let landscape = CGSize(width: proxy.size.height, height: proxy.size.width)
      ZStack {
        TimelineView(.animation) { context in
          let wall = context.date.timeIntervalSinceReferenceDate
          let time = stage == .live ? player.sessionTime(at: context.date) : nil
          Canvas { graphics, size in
            ExhibitionPainter.paint(&graphics, size: size, group: group, wall: wall, time: time)
          }
        }

        VStack(alignment: .trailing, spacing: 2) {
          Text("\(group.members.count) people, one sit")
            .font(DeepType.revealTitle)
            .foregroundStyle(.starlight)
          Text("DEEP · YI PENG, CHIANG MAI")
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(Color.starlight.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 64)
        .padding(.bottom, 26)

        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.starlight)
            .frame(width: 40, height: 40)
            .background(Color.white.opacity(0.12), in: Circle())
        }
        .accessibilityLabel("Close exhibition")
        .accessibilityIdentifier("flower.exhibition.close")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.trailing, 64)
        .padding(.top, 22)
      }
      .frame(width: landscape.width, height: landscape.height)
      .rotationEffect(.degrees(-90))
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .ignoresSafeArea()
    .background(Color.nightIndigo.ignoresSafeArea())
  }
}

private enum ExhibitionPainter {
  static let horizon = 0.8

  static func paint(_ context: inout GraphicsContext, size: CGSize, group: GroupModel, wall: Double, time: Double?) {
    var c = context
    NightPainter.sky(&c, size: size, wall: wall, stars: group.stars, horizon: horizon)
    NightPainter.drifters(&c, size: size, wall: wall, lanterns: group.drifters, floor: horizon * 0.92)

    // Doi Suthep at the horizon, two ridges.
    ridge(&c, size: size, base: horizon * 0.94, height: 0.12, seed: 3, color: Color.duskPlum.mix(with: .emberHaze, by: 0.35))
    var glow = c
    glow.blendMode = .plusLighter
    // City light along the valley.
    glow.fill(
      Path(CGRect(x: 0, y: size.height * (horizon - 0.08), width: size.width, height: size.height * 0.3)),
      with: .linearGradient(
        Gradient(colors: [Color.lanternFlame.opacity(0), Color.lanternFlame.opacity(0.22), Color.lanternFlame.opacity(0)]),
        startPoint: CGPoint(x: 0, y: size.height * (horizon - 0.08)),
        endPoint: CGPoint(x: 0, y: size.height * (horizon + 0.12))
      )
    )

    let members = group.members
      .filter { time == nil || $0.participant.joinedAt <= time! }
      .sorted { $0.depth < $1.depth }
    for member in members {
      lantern(&c, size: size, member: member, wall: wall)
    }
    ridge(&c, size: size, base: horizon + 0.04, height: 0.09, seed: 7, color: .ridgeShadow)
    c.fill(Path(CGRect(x: 0, y: size.height * (horizon + 0.04), width: size.width, height: size.height)), with: .color(.ridgeShadow))
  }

  static func ridge(_ c: inout GraphicsContext, size: CGSize, base: Double, height: Double, seed: UInt64, color: Color) {
    var path = Path()
    path.move(to: CGPoint(x: 0, y: size.height))
    let steps = 60
    for index in 0...steps {
      let x = Double(index) / Double(steps)
      let rise = 0.55 * eegNoise(x * 3.2, seed: seed) + 0.3 * eegNoise(x * 9, seed: seed &+ 1) + 0.15 * eegNoise(x * 23, seed: seed &+ 2)
      path.addLine(to: CGPoint(x: x * size.width, y: size.height * (base - height * (0.55 + 0.45 * rise))))
    }
    path.addLine(to: CGPoint(x: size.width, y: size.height))
    path.closeSubpath()
    c.fill(path, with: .color(color))
  }

  static func lantern(_ c: inout GraphicsContext, size: CGSize, member: GroupMember, wall: Double) {
    let rise = fraction(wall / member.period + member.offset)
    let fade = flowerSmooth(0, 0.08, rise) * (1 - flowerSmooth(0.78, 1, rise))
    guard fade > 0.001 else { return }
    let depth = member.depth
    let lanternSize = (9 + 30 * depth * depth) * (1 - 0.4 * rise)
    let startY = size.height * horizon * (0.98 - 0.12 * (1 - depth))
    let y = startY - rise * (startY + lanternSize * 2)
    let sway = sin(wall * (0.35 + 0.2 * depth) + member.offset * 12)
    let x = member.column * size.width + sway * (6 + 10 * depth) + rise * 30 * (member.offset - 0.5)
    let flicker = 0.85 + 0.15 * sin(wall * 9 + member.offset * 40) * sin(wall * 5.3 + member.offset * 7)
    let strength = fade * (0.55 + 0.45 * depth) * flicker

    var glow = c
    glow.blendMode = .plusLighter
    NightPainter.lanternGlow(&glow, at: CGPoint(x: x, y: y + lanternSize * 0.15), radius: lanternSize * 2.6, strength: strength)

    var l = c
    l.translateBy(x: x, y: y)
    l.rotate(by: .radians(sway * 0.06))
    l.scaleBy(x: lanternSize, y: lanternSize)
    l.opacity = fade * (0.7 + 0.3 * depth)

    // The khom loi: a paper cylinder, wider at the top, open at the bottom.
    var body = Path()
    body.move(to: CGPoint(x: -0.42, y: -0.6))
    body.addQuadCurve(to: CGPoint(x: 0.42, y: -0.6), control: CGPoint(x: 0, y: -0.72))
    body.addQuadCurve(to: CGPoint(x: 0.32, y: 0.58), control: CGPoint(x: 0.47, y: 0))
    body.addQuadCurve(to: CGPoint(x: -0.32, y: 0.58), control: CGPoint(x: 0, y: 0.64))
    body.addQuadCurve(to: CGPoint(x: -0.42, y: -0.6), control: CGPoint(x: -0.47, y: 0))
    body.closeSubpath()
    l.fill(body, with: .linearGradient(
      Gradient(stops: [
        .init(color: Color.lanternFlame.mix(with: .duskPlum, by: 0.35), location: 0),
        .init(color: Color.lanternGold.mix(with: .lanternFlame, by: 0.25), location: 0.45),
        .init(color: Color.lanternGold.mix(with: .starlight, by: 0.55), location: 1)
      ]),
      startPoint: CGPoint(x: 0, y: -0.65), endPoint: CGPoint(x: 0, y: 0.6)
    ))

    // Their flower, printed on the paper and lit from inside.
    var face = l
    face.translateBy(x: 0, y: -0.02)
    face.scaleBy(x: 0.27, y: 0.27)
    for (index, petal) in member.rosette.enumerated() {
      let ink = member.rosetteInks[index]
      face.fill(petal, with: .color(ink.body.mix(with: .lanternFlame, by: 0.18).opacity(0.85)))
    }
    face.fill(disc(.zero, 0.2), with: .color(Color.lanternGold.mix(with: .starlight, by: 0.4)))

    // The flame at the open mouth.
    l.fill(Path(ellipseIn: CGRect(x: -0.13, y: 0.5, width: 0.26, height: 0.16)), with: .radialGradient(
      Gradient(colors: [Color.starlight, Color.lanternFlame.opacity(0)]),
      center: CGPoint(x: 0, y: 0.58), startRadius: 0, endRadius: 0.14
    ))
  }
}

// MARK: - Previews

#Preview("Mine · live") {
  EEGFlowerView(player: EEGSessionPlayer(recording: .fixture(.regular), startAt: 330), stage: .live, tab: .mine)
}

#Preview("Mine · after") {
  EEGFlowerView(player: EEGSessionPlayer(recording: .fixture(.regular)), stage: .after, tab: .mine)
}

#Preview("Together") {
  EEGFlowerView(player: EEGSessionPlayer(recording: .fixture(.regular), startAt: 150), stage: .live, tab: .together)
}

#Preview("Exhibition") {
  EEGFlowerView(player: EEGSessionPlayer(recording: .fixture(.regular)), stage: .after, tab: .together, exhibition: true)
}
#endif
