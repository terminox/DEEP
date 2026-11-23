#if EXPERIMENTS
import SwiftUI

// Lantern: a Yi Peng night over the hills of northern Thailand. Every four seconds
// of the sit a khom loi rises from behind the hills and settles among the others,
// so by the end the sky holds the whole sit. A pure picture, no captions; it reads
// a `LiveSit`, so the same view plays a live demo and a real sit on a Muse 2.
//
// Data → lantern (per four-second window, see `SkyLantern`):
// - band mix → paper colour (alpha amber, theta rose, beta pale, low calm ember)
// - calm → bigger, brighter, steadier
// - a flower on the paper: one petal per slice of the window (alpha green, theta
//   violet, busy rose), more petals when busy, ruffled when restless
// - blinks → a flickering flame; jaw clenches → a wobble
// - a live blink → the newest lantern gutters
// Rising follows the session clock, so lanterns hold still while the sit pauses;
// sway, bob and flicker follow the wall clock, so the sky never freezes.
// Origin: the Exhibition of variant B of the EEG art prototype (`prototype/eeg-art`).

// MARK: - Palette (experiment-local source of truth)

private struct LanternNightColorToken {
  let red: Double
  let green: Double
  let blue: Double
  var color: Color { Color(red: red, green: green, blue: blue) }
}

/// The Yi Peng night. The DEEP palette has no dark sky or lantern light.
private enum LanternNightPalette {
  static let nightIndigo = LanternNightColorToken(red: 0.067, green: 0.071, blue: 0.180)
  static let duskPlum = LanternNightColorToken(red: 0.176, green: 0.106, blue: 0.247)
  static let emberHaze = LanternNightColorToken(red: 0.471, green: 0.239, blue: 0.282)
  static let farRidge = LanternNightColorToken(red: 0.150, green: 0.090, blue: 0.196)
  static let ridgeShadow = LanternNightColorToken(red: 0.090, green: 0.063, blue: 0.137)
  static let lanternFlame = LanternNightColorToken(red: 1.000, green: 0.553, blue: 0.267)
  static let starlight = LanternNightColorToken(red: 1.000, green: 0.965, blue: 0.902)
}

private extension ShapeStyle where Self == Color {
  static var nightIndigo: Color { LanternNightPalette.nightIndigo.color }
  static var duskPlum: Color { LanternNightPalette.duskPlum.color }
  static var emberHaze: Color { LanternNightPalette.emberHaze.color }
  static var farRidge: Color { LanternNightPalette.farRidge.color }
  static var ridgeShadow: Color { LanternNightPalette.ridgeShadow.color }
  static var lanternFlame: Color { LanternNightPalette.lanternFlame.color }
  static var starlight: Color { LanternNightPalette.starlight.color }
}

// MARK: - The art

/// The lantern sky for a sit, live or finished.
struct LanternArtView: View {
  let sit: LiveSit

  var body: some View {
    // A demo loop hands over a new sit: start a new sky with it.
    LanternNight(sit: sit)
      .id(ObjectIdentifier(sit))
      .ignoresSafeArea()
      .accessibilityElement()
      .accessibilityLabel("Lanterns rising into the night sky, one for every few seconds of your sit")
  }
}

/// Owns one sit's sky and advances it each display frame.
private struct LanternNight: View {
  let sit: LiveSit
  @State private var sky: LanternSky
  @State private var inks = LanternInks()

  init(sit: LiveSit) {
    self.sit = sit
    _sky = State(initialValue: LanternSky(length: sit.length))
  }

  var body: some View {
    TimelineView(.animation) { timeline in
      let lanterns = sky.catchUp(with: sit)
      let scene = LanternScene(
        wall: timeline.date.timeIntervalSinceReferenceDate,
        now: sit.sessionTime(at: timeline.date),
        length: sit.length,
        capacity: sky.capacity,
        lanterns: lanterns,
        inks: inks.covering(lanterns),
        lastBlink: sit.recentArtifacts.last { $0.kind == .blink }?.wall
      )
      Canvas { context, size in
        scene.paint(&context, size: size)
      }
    }
  }
}

// MARK: - Lantern geometry and ink

/// The khom loi in its own unit space: a paper cylinder, wider at the top, open
/// at the bottom where the flame burns. About 1.3 tall, 0.94 wide.
private enum LanternShape {
  static let height = 1.3

  static let body = Path { path in
    path.move(to: CGPoint(x: -0.42, y: -0.6))
    path.addQuadCurve(to: CGPoint(x: 0.42, y: -0.6), control: CGPoint(x: 0, y: -0.72))
    path.addQuadCurve(to: CGPoint(x: 0.32, y: 0.58), control: CGPoint(x: 0.47, y: 0))
    path.addQuadCurve(to: CGPoint(x: -0.32, y: 0.58), control: CGPoint(x: 0, y: 0.64))
    path.addQuadCurve(to: CGPoint(x: -0.42, y: -0.6), control: CGPoint(x: -0.47, y: 0))
    path.closeSubpath()
  }

  static let flame = Path(ellipseIn: CGRect(x: -0.13, y: 0.5, width: 0.26, height: 0.16))
  static let flameLight = GraphicsContext.Shading.radialGradient(
    Gradient(colors: [.starlight, Color.lanternFlame.opacity(0)]),
    center: CGPoint(x: 0, y: 0.58), startRadius: 0, endRadius: 0.15
  )

  /// Where the flower is printed: centred on the paper, about half its width.
  static let flowerPrint = CGAffineTransform(translationX: 0, y: -0.02).scaledBy(x: 0.27, y: 0.27)
  static let flowerHeart = Path(ellipseIn: CGRect(x: -0.054, y: -0.074, width: 0.108, height: 0.108))
  /// The flower's pale gold heart, where the flame shows through most.
  static let flowerHeartLight = Color.starlight.mix(with: .lanternFlame, by: 0.3)
  /// Below this height (points) the flower is too small to read, so it is skipped.
  static let flowerMinimumHeight = 14.0

  static let glowCenter = CGPoint(x: 0, y: 0.15)
  static let glowRadius = 2.4
  static let glowDisc = Path(ellipseIn: CGRect(
    x: glowCenter.x - glowRadius, y: glowCenter.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2
  ))
}

/// A lantern's light, built once in the lantern's unit space, so a frame only
/// moves, scales and fades it.
private struct LanternInk {
  let halo: GraphicsContext.Shading
  let paper: GraphicsContext.Shading
  /// The single bright point a distant lantern shrinks to.
  let core: Color
  /// The flower printed on the paper, already placed in lantern space.
  let petals: [(path: Path, color: Color)]

  init(_ lantern: SkyLantern) {
    let light = Color(red: lantern.red, green: lantern.green, blue: lantern.blue)
    halo = .radialGradient(
      Gradient(stops: [
        .init(color: light.opacity(0.55), location: 0),
        .init(color: Color.lanternFlame.opacity(0.16), location: 0.4),
        .init(color: Color.lanternFlame.opacity(0), location: 1)
      ]),
      center: LanternShape.glowCenter, startRadius: 0, endRadius: LanternShape.glowRadius
    )
    // Lit from the flame below: dim at the crown, glowing toward the mouth.
    paper = .linearGradient(
      Gradient(stops: [
        .init(color: light.mix(with: .duskPlum, by: 0.45), location: 0),
        .init(color: light, location: 0.5),
        .init(color: light.mix(with: .starlight, by: 0.55), location: 1)
      ]),
      startPoint: CGPoint(x: 0, y: -0.66), endPoint: CGPoint(x: 0, y: 0.62)
    )
    core = light.mix(with: .starlight, by: 0.4)
    // Printed on lit paper: each petal warmed a little by the flame behind it.
    let shapes = LanternFlowerShape.petals(count: lantern.petals.count, ruffle: lantern.ruffle)
    petals = zip(shapes, lantern.petals).map { shape, tint in
      let color = Color(red: tint.red, green: tint.green, blue: tint.blue)
        .mix(with: .lanternFlame, by: 0.18)
        .opacity(0.85)
      return (shape.applying(LanternShape.flowerPrint), color)
    }
  }
}

/// Each lantern's ink, built the first frame its lantern appears.
private final class LanternInks {
  private var all: [LanternInk] = []

  func covering(_ lanterns: [SkyLantern]) -> [LanternInk] {
    while all.count < lanterns.count { all.append(LanternInk(lanterns[all.count])) }
    return all
  }
}

private struct SkyStar {
  let x: Double
  /// 0 zenith … 1 just above the hills.
  let y: Double
  let radius: Double
  let phase: Double
  let speed: Double
}

// MARK: - The scene

/// One frame of the night: plain values read from the sit, painted in one pass.
private struct LanternScene {
  let wall: Double
  /// Session seconds, smooth between frames.
  let now: Double
  let length: Double
  let capacity: Int
  let lanterns: [SkyLantern]
  let inks: [LanternInk]
  let lastBlink: Double?

  /// Session seconds a lantern takes to climb to its resting place.
  private static let climb = 36.0
  /// Where the near hills crest, as a fraction of the height.
  private static let hillLine = 0.87

  private static let stars: [SkyStar] = {
    var random = SeededRandom(seed: 8_812)
    return (0..<150).map { _ in
      SkyStar(
        x: random.unit(),
        y: pow(random.unit(), 1.4),
        radius: 0.35 + pow(random.unit(), 3) * 1.2,
        phase: random.unit() * 2 * .pi,
        speed: 0.6 + random.unit() * 1.8
      )
    }
  }()

  func paint(_ c: inout GraphicsContext, size: CGSize) {
    // The dusk deepens into night over the sit.
    let night = eegSmoothstep(0, length, now)
    paintSky(&c, size: size, night: night)
    c.fill(ridge(in: size, base: 0.84, height: 0.1, seed: 3), with: .color(.farRidge))
    paintLanterns(&c, size: size)
    c.fill(ridge(in: size, base: 0.93, height: 0.07, seed: 7), with: .color(.ridgeShadow))
  }

  private func paintSky(_ c: inout GraphicsContext, size: CGSize, night: Double) {
    let h = size.height
    c.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
      Gradient(stops: [
        .init(color: .nightIndigo, location: 0),
        .init(color: Color.duskPlum.mix(with: .nightIndigo, by: 0.4 * night), location: 0.6),
        .init(color: Color.emberHaze.mix(with: .duskPlum, by: 0.55 * night), location: 1)
      ]),
      startPoint: .zero, endPoint: CGPoint(x: 0, y: h * Self.hillLine)
    ))

    var light = c
    light.blendMode = .plusLighter
    let starStrength = 0.55 + 0.45 * night
    for star in Self.stars {
      let twinkle = 0.45 + 0.55 * (0.5 + 0.5 * sin(wall * star.speed + star.phase))
      let fade = 1 - eegSmoothstep(0.55, 0.9, star.y)
      let point = CGPoint(x: star.x * size.width, y: star.y * h * Self.hillLine * 0.85)
      light.fill(disc(point, star.radius), with: .color(Color.starlight.opacity(0.8 * twinkle * fade * starStrength)))
    }

    // The valley warms as her lanterns fill the sky.
    let filled = Double(lanterns.count) / Double(max(capacity, 1))
    let band = CGRect(x: 0, y: h * (Self.hillLine - 0.16), width: size.width, height: h * 0.24)
    light.fill(Path(band), with: .linearGradient(
      Gradient(colors: [
        Color.lanternFlame.opacity(0),
        Color.lanternFlame.opacity(0.06 + 0.14 * filled),
        Color.lanternFlame.opacity(0)
      ]),
      startPoint: CGPoint(x: 0, y: band.minY), endPoint: CGPoint(x: 0, y: band.maxY)
    ))
  }

  /// Far lanterns first, so near ones pass in front.
  private func paintLanterns(_ c: inout GraphicsContext, size: CGSize) {
    guard !lanterns.isEmpty else { return }
    // Lanterns shrink a little as more share the sky: 45 full size, 150 at 70%.
    let crowding = pow(45 / Double(max(capacity, 45)), 0.3)
    let unit = min(size.width, size.height) * 0.075 * crowding
    let newest = lanterns.count - 1
    let blinkAge = lastBlink.map { wall - $0 } ?? .infinity

    for index in lanterns.indices.sorted(by: { lanterns[$0].depth < lanterns[$1].depth }) {
      let lantern = lanterns[index]
      let age = now - lantern.releasedAt
      guard age > 0 else { continue }
      let climbed = 1 - pow(1 - min(age / Self.climb, 1), 3)
      let depth = lantern.depth
      let spin = lantern.phase * 2 * .pi

      // Place: up from behind the hills on an ease-out, drifting and swaying.
      let launchY = size.height * 0.97
      let restY = size.height * lantern.rest
      let bob = sin(wall * (0.35 + 0.2 * lantern.phase) + spin) * (1.2 + 2.2 * depth)
      let y = launchY + (restY - launchY) * climbed + bob
      let swing = sin(wall * (0.18 + 0.14 * depth) * (1 + 0.5 * lantern.wobble) + spin * 3)
      let sway = swing * (2 + 7 * depth) * (1.35 - 0.5 * lantern.steadiness) * (1 + 1.2 * lantern.wobble)
      let drift = (lantern.phase - 0.5) * 0.06 * size.width * climbed
        + eegNoise(wall * 0.02 + lantern.phase * 50, seed: 5) * (4 + 10 * depth)
      let x = (0.06 + 0.88 * lantern.column) * size.width + drift + sway
      let height = unit * lantern.size * (0.4 + 0.6 * depth) * (1 - 0.12 * climbed)

      // Light: calm and depth set the strength; the newest burn brightest.
      let rank = Double(newest - index)
      let focus = 1 + 0.45 * exp(-rank / 1.2)
      let flame = 1 + (0.05 + 0.3 * lantern.flicker) * sin(wall * 9.1 + spin * 40) * sin(wall * 5.3 + spin * 17)
      let gutter = index == newest && (0..<0.6).contains(blinkAge) ? 1 - 0.55 * sin(2 * .pi * blinkAge / 0.6) : 1
      let fadeIn = eegSmoothstep(0, 1.5, age)
      let strength = lantern.glow * (0.45 + 0.55 * depth) * flame * focus * gutter * fadeIn

      var base = c
      base.translateBy(x: x, y: y)
      base.rotate(by: .radians(swing * 0.05 * (1 + lantern.wobble)))
      base.scaleBy(x: height / LanternShape.height, y: height / LanternShape.height)
      let ink = inks[index]

      var halo = base
      halo.blendMode = .plusLighter
      halo.opacity = min(strength * 0.8 * crowding, 1)
      halo.fill(LanternShape.glowDisc, with: ink.halo)

      guard height >= 8 else {
        c.fill(disc(CGPoint(x: x, y: y), max(height * 0.18, 0.8)), with: .color(ink.core.opacity(min(strength, 1))))
        continue
      }
      var paper = base
      paper.opacity = fadeIn * (0.62 + 0.38 * depth) * min(0.75 + 0.25 * flame * gutter, 1)
      paper.fill(LanternShape.body, with: ink.paper)
      if height >= LanternShape.flowerMinimumHeight {
        for petal in ink.petals { paper.fill(petal.path, with: .color(petal.color)) }
        paper.fill(LanternShape.flowerHeart, with: .color(LanternShape.flowerHeartLight))
      }

      var fire = base
      fire.blendMode = .plusLighter
      fire.opacity = min(strength, 1)
      fire.fill(LanternShape.flame, with: LanternShape.flameLight)
    }
  }

  /// A soft, seeded hill line, filled down to the bottom edge.
  private func ridge(in size: CGSize, base: Double, height: Double, seed: UInt64) -> Path {
    Path { path in
      path.move(to: CGPoint(x: 0, y: size.height))
      let steps = 60
      for step in 0...steps {
        let u = Double(step) / Double(steps)
        let rise = 0.55 * eegNoise(u * 3.2, seed: seed) + 0.3 * eegNoise(u * 9, seed: seed &+ 1)
          + 0.15 * eegNoise(u * 23, seed: seed &+ 2)
        path.addLine(to: CGPoint(x: u * size.width, y: size.height * (base - height * (0.55 + 0.45 * rise))))
      }
      path.addLine(to: CGPoint(x: size.width, y: size.height))
      path.closeSubpath()
    }
  }

  private func disc(_ center: CGPoint, _ radius: Double) -> Path {
    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
  }
}

// MARK: - Previews

#Preview("Lantern · 2 min in") {
  LanternArtView(sit: .replaying(.regular, length: 300, upTo: 120))
}

#Preview("Lantern · finished 10 min") {
  LanternArtView(sit: .replaying(.regular, length: 600))
}

#Preview("Lantern · landscape", traits: .landscapeLeft) {
  LanternArtView(sit: .replaying(.regular, length: 180, upTo: 150))
}

#endif
