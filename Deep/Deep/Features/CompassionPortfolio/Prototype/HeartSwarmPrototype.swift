#if DEBUG
import SwiftUI

// PROTOTYPE, throwaway. One particle field of hearts, in four temperaments:
// rise (A), arc into a target (B, D), confetti (E) and depth bokeh (C).

/// The random part of a swarm, rolled once so the parent can know when each
/// heart lands (to time haptics and beats) without reading the canvas.
struct HeartSwarmPlan {
  enum Mode { case rise, arc, confetti, bokeh }

  struct Particle {
    let delay: Double
    let life: Double
    let size: CGFloat
    let tone: Int
    let depth: Int
    /// Free random numbers, each mode reads them its own way.
    let a: Double, b: Double, c: Double, d: Double
  }

  let mode: Mode
  let particles: [Particle]

  var duration: Double { particles.map { $0.delay + $0.life }.max() ?? 0 }
  /// When each heart reaches its target (arc), soonest first.
  var arrivals: [Double] { particles.map { $0.delay + $0.life }.sorted() }

  init(mode: Mode, budget: Int, seed: UInt64 = .random(in: 0...UInt64.max)) {
    self.mode = mode
    var rng = SplitMix(seed: seed)
    let count: Int = switch mode {
    case .rise, .arc: budget
    case .confetti: Swift.min(48, budget * 2)
    case .bokeh: Swift.min(36, budget * 3 / 2)
    }
    let tones = Self.tones(for: mode)
    particles = (0..<count).map { i in
      let r = { rng.unit() }
      let s = { rng.signed() }
      let tone = tones[Int(r() * Double(tones.count)) % tones.count]
      switch mode {
      case .rise:
        return Particle(
          delay: Double(i) * 0.07 + r() * 0.12, life: 1.8 + r() * 0.7,
          size: 16 + r() * 18, tone: tone, depth: 0,
          a: s(), b: r(), c: r(), d: r()
        )
      case .arc:
        return Particle(
          delay: Double(i) * 0.07, life: 0.85 + r() * 0.2,
          size: 18 + r() * 10, tone: tone, depth: 0,
          a: s(), b: s(), c: r(), d: r()
        )
      case .confetti:
        return Particle(
          delay: r() * 0.08, life: 2.2 + r() * 0.6,
          size: 12 + r() * 10, tone: tone, depth: 0,
          a: s(), b: r(), c: s(), d: r()
        )
      case .bokeh:
        let depth = Int(r() * 3) % 3
        let size: CGFloat = switch depth {
        case 0: 14 + r() * 8
        case 1: 22 + r() * 12
        default: 36 + r() * 24
        }
        return Particle(
          delay: Double(i) * (2.4 / Double(count)) + r() * 0.3, life: 3.5 + r() * 1.5,
          size: size, tone: tone, depth: depth,
          a: r(), b: r(), c: r(), d: r()
        )
      }
    }
  }

  /// Indexes into `HeartSwarmPrototype.palette`, repeated for weight.
  private static func tones(for mode: Mode) -> [Int] {
    switch mode {
    // Peach reads as beige over the pale atmosphere, so the flying hearts keep
    // to the rose and lavender end of the palette.
    case .rise, .arc: [0, 0, 1, 1, 2, 4]
    case .confetti: [0, 1, 1, 2, 3, 4]
    case .bokeh: [0, 0, 1, 4, 5, 2]
    }
  }
}

private struct SplitMix {
  var state: UInt64
  init(seed: UInt64) { state = seed }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
  mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
  mutating func signed() -> Double { unit() * 2 - 1 }
}

struct HeartSwarmPrototype: View {
  static let palette: [Color] = [.blushPowder, .duskRose, .lavenderMist, .peachCloud, .softLilac, .moonCream]
  private static let symbolSize: CGFloat = 32

  let plan: HeartSwarmPlan
  /// Where hearts start, in this view's space. Ignored by bokeh.
  var origin: CGPoint = .zero
  /// Where arc hearts land, in this view's space.
  var target: CGPoint = .zero

  @State private var start = Date.now
  @State private var finished = false

  var body: some View {
    TimelineView(.animation(paused: finished)) { timeline in
      let t = timeline.date.timeIntervalSince(start)
      Canvas { ctx, size in
        guard !finished else { return }
        draw(in: &ctx, size: size, time: t)
      } symbols: {
        ForEach(Self.palette.indices, id: \.self) { i in
          Image(systemName: "heart.fill")
            .font(.system(size: Self.symbolSize, weight: .bold))
            .foregroundStyle(Self.palette[i])
            .tag(i)
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .task {
      try? await Task.sleep(for: .seconds(plan.duration))
      finished = true
    }
  }

  private func draw(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
    switch plan.mode {
    case .bokeh:
      for depth in 0..<3 {
        ctx.drawLayer { layer in
          if depth > 0 { layer.addFilter(.blur(radius: depth == 1 ? 1.5 : 5)) }
          for p in plan.particles where p.depth == depth {
            drawParticle(p, in: &layer, size: size, time: time)
          }
        }
      }
    default:
      ctx.drawLayer { layer in
        layer.addFilter(.shadow(color: Color.lavenderMist.opacity(0.45), radius: 6, y: 2))
        for p in plan.particles {
          drawParticle(p, in: &layer, size: size, time: time)
        }
      }
    }
  }

  private struct Pose {
    var position: CGPoint
    var scale: CGFloat
    var scaleX: CGFloat = 1
    var opacity: Double
    var angle: Double
  }

  private func drawParticle(_ p: HeartSwarmPlan.Particle, in ctx: inout GraphicsContext, size: CGSize, time: Double) {
    let local = time - p.delay
    guard local >= 0, local <= p.life, let symbol = ctx.resolveSymbol(id: p.tone) else { return }
    let progress = local / p.life
    let pose = switch plan.mode {
    case .rise: rise(p, progress)
    case .arc: arc(p, progress)
    case .confetti: confetti(p, local, progress)
    case .bokeh: bokeh(p, progress, size)
    }
    var g = ctx
    g.opacity = pose.opacity
    g.translateBy(x: pose.position.x, y: pose.position.y)
    g.rotate(by: .radians(pose.angle))
    let s = p.size / Self.symbolSize * pose.scale
    g.scaleBy(x: s * pose.scaleX, y: s)
    g.draw(symbol, at: .zero)
  }

  private func rise(_ p: HeartSwarmPlan.Particle, _ t: Double) -> Pose {
    let eased = 1 - pow(1 - t, 2.2)
    let sway = sin((t * p.life * 0.9 + p.c) * 2 * .pi) * (8 + 18 * p.b) * Swift.min(1, t * 4)
    return Pose(
      position: CGPoint(
        x: origin.x + (p.c - 0.5) * 140 + p.a * 120 * eased + sway,
        y: origin.y - (220 + 300 * p.d) * eased
      ),
      scale: t < 0.12 ? 0.4 + 0.6 * (t / 0.12) : 1,
      opacity: t < 0.08 ? t / 0.08 : (t > 0.5 ? 1 - (t - 0.5) / 0.5 : 1),
      angle: sin(t * 6 + p.c * 6) * 0.18
    )
  }

  private func arc(_ p: HeartSwarmPlan.Particle, _ t: Double) -> Pose {
    let e = t * t * (3 - 2 * t)
    let from = CGPoint(x: origin.x + p.b * 28, y: origin.y)
    let mid = CGPoint(x: (from.x + target.x) / 2, y: (from.y + target.y) / 2)
    let dx = target.x - from.x, dy = target.y - from.y
    let length = Swift.max(hypot(dx, dy), 1)
    // Bend sideways off the straight line, a little more for long flights.
    let bend = p.a * Swift.min(160, length * 0.45)
    let control = CGPoint(x: mid.x - dy / length * bend, y: mid.y + dx / length * bend - 40)
    let u = 1 - e
    let point = CGPoint(
      x: u * u * from.x + 2 * u * e * control.x + e * e * target.x,
      y: u * u * from.y + 2 * u * e * control.y + e * e * target.y
    )
    return Pose(
      position: point,
      scale: t < 0.25 ? 0.5 + 0.6 * (t / 0.25) : 1.1 - 0.7 * ((t - 0.25) / 0.75),
      opacity: t < 0.06 ? t / 0.06 : (t > 0.88 ? 1 - (t - 0.88) / 0.12 : 1),
      angle: sin(t * 5 + p.c * 6) * 0.2
    )
  }

  private func confetti(_ p: HeartSwarmPlan.Particle, _ s: Double, _ t: Double) -> Pose {
    let theta = -Double.pi / 2 + p.a * 0.95
    let speed = 950 + 650 * p.b
    let k = 1.4, g = 950.0
    let decay = (1 - exp(-k * s)) / k
    let vx = cos(theta) * speed, vy = sin(theta) * speed
    let flutter = sin(s * 7 + p.d * 6) * 12 * Swift.min(1, s * 2)
    return Pose(
      position: CGPoint(
        x: origin.x + vx * decay + flutter,
        y: origin.y + (g / k) * s + (vy - g / k) * decay
      ),
      scale: 1,
      scaleX: Swift.max(0.2, abs(cos(s * 5 + p.d * 6))),
      opacity: t > 0.7 ? 1 - (t - 0.7) / 0.3 : 1,
      angle: p.c * 5 * s
    )
  }

  private func bokeh(_ p: HeartSwarmPlan.Particle, _ t: Double, _ size: CGSize) -> Pose {
    let travel = size.height * (0.75 + 0.45 * p.d)
    let ceiling: Double = [0.95, 0.7, 0.45][p.depth]
    let fade = t < 0.15 ? t / 0.15 : (t > 0.65 ? 1 - (t - 0.65) / 0.35 : 1)
    return Pose(
      position: CGPoint(
        x: p.a * size.width + sin((t * p.life * 0.4 + p.c) * 2 * .pi) * (10 + 20 * p.b),
        y: size.height + p.size - travel * (1 - pow(1 - t, 1.6))
      ),
      scale: 1,
      opacity: fade * ceiling,
      angle: sin(t * 3 + p.c * 6) * 0.15
    )
  }
}

#Preview("Heart swarm") {
  @Previewable @State var run = 0
  @Previewable @State var mode = HeartSwarmPlan.Mode.rise
  GeometryReader { proxy in
    ZStack {
      AtmosphereBackground()
      HeartSwarmPrototype(
        plan: HeartSwarmPlan(mode: mode, budget: 24),
        origin: CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.75),
        target: CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.2)
      )
      .id(run)
      VStack {
        Spacer()
        HStack {
          Button("Rise") { mode = .rise; run += 1 }
          Button("Arc") { mode = .arc; run += 1 }
          Button("Confetti") { mode = .confetti; run += 1 }
          Button("Bokeh") { mode = .bokeh; run += 1 }
        }
        .padding(.bottom, 40)
      }
    }
  }
}
#endif
