import SwiftUI

/// A gift made visible: hearts lift off one point and drift up through the
/// screen on slow, swaying paths, then fade — floating particles, the motion
/// DESIGN.md asks for, rather than a burst.
///
/// The field is rolled once, when the view appears, so no two gifts rise the
/// same way. It plays a single time; once the last heart has faded the
/// timeline pauses and the canvas draws nothing, so the view can stay mounted
/// under whatever comes next without costing a frame. Callers skip it under
/// Reduce Motion.
struct RisingHearts: View {
  /// How many hearts a gift of `amount` sends up. Grows with the gift so a
  /// hundred feels fuller than one, but on a log scale and capped, so the
  /// largest gift is still a drift rather than a flood: 1 → 5, 10 → 18,
  /// about 30 and beyond → 24.
  static func count(for amount: Int) -> Int {
    Swift.min(24, 5 + Int(4 * log2(Double(Swift.max(amount, 1)))))
  }

  /// Mostly moon-white, with a blush and a peach heart among them. The
  /// lavender shadow below is what seats the white against the pale
  /// atmosphere. Repeats are weights.
  private static let tones: [Color] = [.moonCream, .moonCream, .moonCream, .moonCream, .blushPowder, .peachCloud]
  private static let symbolSize: CGFloat = 32

  /// Where the hearts lift off, in this view's own space.
  let origin: CGPoint

  @State private var hearts: [Heart]
  @State private var start = Date.now
  @State private var settled = false

  init(count: Int, origin: CGPoint) {
    self.origin = origin
    _hearts = State(initialValue: (0..<count).map(Heart.init(index:)))
  }

  var body: some View {
    TimelineView(.animation(paused: settled)) { timeline in
      let elapsed = timeline.date.timeIntervalSince(start)
      Canvas { context, _ in
        guard !settled else { return }
        context.drawLayer { layer in
          layer.addFilter(.shadow(color: Color.lavenderMist.opacity(0.45), radius: 6, y: 2))
          for heart in hearts {
            draw(heart, at: elapsed, in: &layer)
          }
        }
      } symbols: {
        ForEach(Self.tones.indices, id: \.self) { index in
          Image(systemName: "heart.fill")
            .font(.system(size: Self.symbolSize, weight: .bold))
            .foregroundStyle(Self.tones[index])
            .tag(index)
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .task {
      let lastFade = hearts.map { $0.delay + $0.life }.max() ?? 0
      try? await Task.sleep(for: .seconds(lastFade))
      settled = true
    }
  }

  private func draw(_ heart: Heart, at elapsed: Double, in context: inout GraphicsContext) {
    let age = elapsed - heart.delay
    guard age >= 0, age <= heart.life, let symbol = context.resolveSymbol(id: heart.tone) else { return }
    let t = age / heart.life
    let lift = 1 - pow(1 - t, 2.2)
    // The sway grows in over the first quarter, so every heart leaves the
    // button from the same place before the field spreads.
    let sway = sin((t * heart.life * 0.9 + heart.phase) * 2 * .pi) * heart.swayWidth * Swift.min(1, t * 4)

    var pen = context
    pen.opacity = t < 0.08 ? t / 0.08 : (t > 0.5 ? 1 - (t - 0.5) / 0.5 : 1)
    pen.translateBy(
      x: origin.x + heart.launch + heart.spread * lift + sway,
      y: origin.y - heart.height * lift
    )
    pen.rotate(by: .radians(sin(t * 6 + heart.phase * 6) * 0.18))
    let bloom = t < 0.12 ? 0.4 + 0.6 * (t / 0.12) : 1
    let scale = heart.size / Self.symbolSize * bloom
    pen.scaleBy(x: scale, y: scale)
    pen.draw(symbol, at: .zero)
  }
}

/// One heart's random path, rolled once.
private struct Heart {
  let delay: Double
  let life: Double
  let size: CGFloat
  let tone: Int
  /// Sideways offset at lift-off, across the button's width.
  let launch: Double
  /// Further sideways travel over the rise.
  let spread: Double
  let height: Double
  let swayWidth: Double
  let phase: Double

  init(index: Int) {
    delay = Double(index) * 0.07 + .random(in: 0...0.12)
    life = .random(in: 1.8...2.5)
    size = .random(in: 16...34)
    tone = .random(in: 0..<6)
    launch = .random(in: -70...70)
    spread = .random(in: -120...120)
    height = .random(in: 220...520)
    swayWidth = .random(in: 8...26)
    phase = .random(in: 0...1)
  }
}

#Preview("Rising hearts") {
  @Previewable @State var gift = 0
  @Previewable @State var amount = 10
  GeometryReader { proxy in
    ZStack {
      AtmosphereBackground()
      if gift > 0 {
        RisingHearts(
          count: RisingHearts.count(for: amount),
          origin: CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.8)
        )
        .id(gift)
      }
      VStack {
        Spacer()
        HStack(spacing: 24) {
          ForEach([1, 10, 100], id: \.self) { value in
            Button {
              amount = value
              gift += 1
            } label: {
              Text(verbatim: "Give \(value)")
            }
          }
        }
        .padding(.bottom, 48)
      }
    }
  }
}
