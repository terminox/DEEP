import SwiftUI

/// Six continents the map knows about. Each carries a color from the Deep
/// palette so continents are distinguishable without labels.
enum Continent: CaseIterable, Hashable {
  case northAmerica
  case southAmerica
  case europe
  case africa
  case asia
  case oceania

  var color: Color {
    switch self {
    case .northAmerica: return DeepColor.peachCloud
    case .southAmerica: return DeepColor.skyWash
    case .europe:       return DeepColor.blushPowder
    case .africa:       return DeepColor.softLilac
    case .asia:         return DeepColor.lavenderMist
    case .oceania:      return DeepColor.peachCloud
    }
  }

  fileprivate var centroid: CGPoint {
    switch self {
    case .northAmerica: return CGPoint(x: 0.17, y: 0.30)
    case .southAmerica: return CGPoint(x: 0.30, y: 0.70)
    case .europe:       return CGPoint(x: 0.50, y: 0.30)
    case .africa:       return CGPoint(x: 0.54, y: 0.58)
    case .asia:         return CGPoint(x: 0.70, y: 0.33)
    case .oceania:      return CGPoint(x: 0.86, y: 0.71)
    }
  }

  fileprivate var glowRadiusFactor: CGFloat {
    switch self {
    case .asia:                       return 0.36
    case .africa, .northAmerica:      return 0.30
    case .southAmerica:               return 0.22
    case .europe:                     return 0.18
    case .oceania:                    return 0.17
    }
  }

  /// Continent silhouettes as unions of normalized ellipses. Tuned by eye for
  /// recognizability at low dot density, not for cartographic accuracy.
  fileprivate static let regions: [(Continent, [Ellipse])] = [
    (.northAmerica, [
      Ellipse(cx: 0.16, cy: 0.27, rx: 0.10, ry: 0.10),
      Ellipse(cx: 0.20, cy: 0.20, rx: 0.08, ry: 0.05),
      Ellipse(cx: 0.21, cy: 0.36, rx: 0.05, ry: 0.05),
      Ellipse(cx: 0.22, cy: 0.45, rx: 0.04, ry: 0.05),
      Ellipse(cx: 0.10, cy: 0.27, rx: 0.04, ry: 0.05),
      Ellipse(cx: 0.27, cy: 0.20, rx: 0.04, ry: 0.05)
    ]),
    (.southAmerica, [
      Ellipse(cx: 0.29, cy: 0.60, rx: 0.05, ry: 0.06),
      Ellipse(cx: 0.30, cy: 0.70, rx: 0.04, ry: 0.08),
      Ellipse(cx: 0.32, cy: 0.80, rx: 0.02, ry: 0.04)
    ]),
    (.europe, [
      Ellipse(cx: 0.49, cy: 0.28, rx: 0.05, ry: 0.05),
      Ellipse(cx: 0.52, cy: 0.32, rx: 0.04, ry: 0.04),
      Ellipse(cx: 0.47, cy: 0.33, rx: 0.03, ry: 0.04)
    ]),
    (.africa, [
      Ellipse(cx: 0.52, cy: 0.48, rx: 0.07, ry: 0.06),
      Ellipse(cx: 0.55, cy: 0.58, rx: 0.06, ry: 0.08),
      Ellipse(cx: 0.56, cy: 0.66, rx: 0.04, ry: 0.06)
    ]),
    (.asia, [
      Ellipse(cx: 0.68, cy: 0.29, rx: 0.13, ry: 0.10),
      Ellipse(cx: 0.62, cy: 0.30, rx: 0.06, ry: 0.06),
      Ellipse(cx: 0.78, cy: 0.27, rx: 0.07, ry: 0.07),
      Ellipse(cx: 0.68, cy: 0.45, rx: 0.04, ry: 0.05),
      Ellipse(cx: 0.77, cy: 0.50, rx: 0.05, ry: 0.04),
      Ellipse(cx: 0.83, cy: 0.50, rx: 0.04, ry: 0.03)
    ]),
    (.oceania, [
      Ellipse(cx: 0.85, cy: 0.70, rx: 0.06, ry: 0.05),
      Ellipse(cx: 0.92, cy: 0.77, rx: 0.02, ry: 0.03)
    ])
  ]

  fileprivate struct Ellipse {
    let cx: Double
    let cy: Double
    let rx: Double
    let ry: Double
  }

  fileprivate static func containing(x: Double, y: Double) -> Continent? {
    for (continent, ellipses) in regions {
      for e in ellipses {
        let dx = (x - e.cx) / e.rx
        let dy = (y - e.cy) / e.ry
        if dx * dx + dy * dy <= 1.0 { return continent }
      }
    }
    return nil
  }
}

/// A dotted world map. Each continent glows with intensity 0...1 — a measure
/// of live participation in that region. A slow breathing pulse modulates the
/// whole field on the 4s inhale / 6s exhale rhythm. Optionally, one continent
/// can be marked as the viewer's own; a single soft halo emanates from it.
struct WorldDotMap: View {
  let activity: [Continent: Double]
  let viewerContinent: Continent?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let dots: [Dot]

  init(activity: [Continent: Double] = [:], viewerContinent: Continent? = nil) {
    self.activity = activity
    self.viewerContinent = viewerContinent
    self.dots = WorldDotMap.makeDots(cols: 96, rows: 48)
  }

  var body: some View {
    GeometryReader { geo in
      TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 : 1.0/30.0, paused: false)) { context in
        Canvas(opaque: false, rendersAsynchronously: false) { ctx, size in
          let t = context.date.timeIntervalSinceReferenceDate
          let pulse = breathingPulse(t: t)

          drawContinentHaze(ctx: ctx, size: size, pulse: pulse)
          drawDots(ctx: ctx, size: size, pulse: pulse)
          drawViewerHalo(ctx: ctx, size: size, t: t)
        }
        .frame(width: geo.size.width, height: geo.size.width * 0.5)
        .frame(maxHeight: geo.size.height, alignment: .center)
      }
    }
    .aspectRatio(2, contentMode: .fit)
    .accessibilityHidden(true)
  }

  // MARK: - Drawing

  private func drawContinentHaze(ctx: GraphicsContext, size: CGSize, pulse: Double) {
    for continent in Continent.allCases {
      let base = activity[continent] ?? 0
      let bumped = (continent == viewerContinent) ? min(1.0, base + 0.12) : base
      let glow = (0.10 + bumped * 0.55) * pulse
      guard glow > 0.02 else { continue }

      let centroid = continent.centroid
      let center = CGPoint(x: centroid.x * size.width, y: centroid.y * size.height)
      let radius = min(size.width, size.height) * continent.glowRadiusFactor * (1.6 + 0.4 * bumped)
      let rect = CGRect(
        x: center.x - radius, y: center.y - radius,
        width: radius * 2, height: radius * 2
      )

      let gradient = Gradient(stops: [
        .init(color: continent.color.opacity(glow), location: 0.0),
        .init(color: continent.color.opacity(glow * 0.4), location: 0.45),
        .init(color: continent.color.opacity(0.0), location: 1.0)
      ])
      ctx.fill(
        Path(ellipseIn: rect),
        with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius)
      )
    }
  }

  private func drawDots(ctx: GraphicsContext, size: CGSize, pulse: Double) {
    let dotRadius: CGFloat = max(1.1, size.width / 320)
    let outerRadius = dotRadius * 2.4

    for dot in dots {
      let intensity = activity[dot.continent] ?? 0
      let bumped = (dot.continent == viewerContinent) ? min(1.0, intensity + 0.08) : intensity
      let px = dot.x * size.width
      let py = dot.y * size.height
      let color = dot.continent.color

      // Soft outer halo per active dot.
      if bumped > 0.10 {
        let haloOpacity = bumped * 0.30 * pulse
        let r = outerRadius * (0.9 + bumped * 0.4)
        let rect = CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(haloOpacity)))
      }

      // The dot itself.
      let baseOpacity = 0.28 + bumped * 0.55
      let rect = CGRect(
        x: px - dotRadius, y: py - dotRadius,
        width: dotRadius * 2, height: dotRadius * 2
      )
      ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(baseOpacity * pulse)))
    }
  }

  private func drawViewerHalo(ctx: GraphicsContext, size: CGSize, t: Double) {
    guard let viewer = viewerContinent else { return }
    let centroid = viewer.centroid
    let center = CGPoint(x: centroid.x * size.width, y: centroid.y * size.height)
    // One soft slow ring expanding-and-fading every ~6s.
    let cycle = t.truncatingRemainder(dividingBy: 6.0) / 6.0
    let baseRadius = min(size.width, size.height) * 0.06
    let ringRadius = baseRadius + baseRadius * 1.5 * cycle
    let alpha = (1 - cycle) * 0.22
    let rect = CGRect(
      x: center.x - ringRadius, y: center.y - ringRadius,
      width: ringRadius * 2, height: ringRadius * 2
    )
    var path = Path()
    path.addEllipse(in: rect)
    ctx.stroke(path, with: .color(.white.opacity(alpha)), lineWidth: 0.8)
  }

  // MARK: - Motion

  /// Asymmetric 4s inhale / 6s exhale, eased.
  private func breathingPulse(t: Double) -> Double {
    guard !reduceMotion else { return 1.0 }
    let cycle = t.truncatingRemainder(dividingBy: 10.0)
    let phase: Double = cycle < 4 ? cycle / 4.0 : 1.0 - (cycle - 4.0) / 6.0
    let smoothed = 0.5 - 0.5 * cos(phase * .pi)
    return 0.78 + 0.22 * smoothed
  }

  // MARK: - Dot generation

  private static func makeDots(cols: Int, rows: Int) -> [Dot] {
    var dots: [Dot] = []
    dots.reserveCapacity(cols * rows / 3)
    for r in 0..<rows {
      for c in 0..<cols {
        let x = (Double(c) + 0.5) / Double(cols)
        let y = (Double(r) + 0.5) / Double(rows)
        if let continent = Continent.containing(x: x, y: y) {
          // Sub-cell jitter for an organic, non-gridded read.
          let jx = sin(Double(c) * 12.9898 + Double(r) * 78.233).truncatingRemainder(dividingBy: 1)
          let jy = sin(Double(c) * 4.1414 + Double(r) * 39.6243).truncatingRemainder(dividingBy: 1)
          let jitterX = jx * 0.4 / Double(cols)
          let jitterY = jy * 0.4 / Double(rows)
          dots.append(Dot(x: x + jitterX, y: y + jitterY, continent: continent))
        }
      }
    }
    return dots
  }

  fileprivate struct Dot {
    let x: Double
    let y: Double
    let continent: Continent
  }
}

#Preview("World map · idle") {
  ZStack {
    DuskAtmosphereBackground()
    WorldDotMap()
      .padding(.horizontal, 20)
  }
}

#Preview("World map · live activity") {
  ZStack {
    DuskAtmosphereBackground()
    WorldDotMap(
      activity: [
        .asia: 0.9,
        .europe: 0.55,
        .northAmerica: 0.35,
        .africa: 0.25,
        .southAmerica: 0.15,
        .oceania: 0.45
      ],
      viewerContinent: .asia
    )
    .padding(.horizontal, 20)
  }
}
