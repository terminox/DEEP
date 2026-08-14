import SwiftUI

/// The production night-sky configuration, mirroring `EarthTuning`'s shape:
/// a shared instance read by `GlobalPauseCardView` (the session's night mode)
/// and a nested `Values` struct whose defaults ARE the shipped look — nothing
/// writes at runtime.
@MainActor
@Observable
final class NightSkyTuning {
  static let shared = NightSkyTuning()

  struct Values: Codable, Equatable {
    // MARK: Sky
    /// Top-of-sky darkness: 0 = twilight plum (DuskAtmosphere's lightest
    /// stop), 1 = near-black plum.
    var skyTopDarkness: Float = 0.90
    /// Bottom-of-sky darkness on the same ramp — lower than the top so the
    /// horizon lifts.
    var skyBottomDarkness: Float = 0.60
    /// Alpha of the softLilac glow hugging the bottom edge. 0 = off.
    var horizonGlow: Float = 0.22

    // MARK: Stars
    /// Star population. Regenerates the field (together with `seed`).
    var starCount: Int = 90
    /// Core radius range in points; each star lerps between them.
    var starSizeMin: Float = 0.5
    var starSizeMax: Float = 1.8
    /// Base alpha range; each star lerps between them.
    var brightnessMin: Float = 0.3
    var brightnessMax: Float = 1.0

    // MARK: Twinkle
    /// Base twinkle frequency in cycles/second (jittered ±40% per star).
    var twinkleSpeed: Float = 0.5
    /// Brightness modulation depth: 0 = steady, 1 = fades fully out.
    var twinkleDepth: Float = 0.5
    /// Fraction of the population that twinkles (the rest hold steady).
    var twinkleShare: Float = 0.6

    // MARK: Tint
    /// How far off-cream the tinted half of the population drifts:
    /// 0 = all moonCream, 1 = fully at the cool target.
    var tintSpread: Float = 0.5
    /// The cool target: 0 = skyWash (icy blue), 1 = lavenderMist.
    var tintBalance: Float = 0.4

    // MARK: Glow
    /// Halo radius as a multiple of the core radius. ≤1 disables the halo.
    var glowScale: Float = 2.6
    /// Halo peak alpha as a fraction of the star's current brightness.
    var glowAlpha: Float = 0.35

    // MARK: Layout
    /// Fraction of the view height at the bottom over which star alpha
    /// smoothsteps out, thinning the field toward the horizon. 0 = no fade.
    var horizonFade: Float = 0.35
    /// Star field seed — reroll for a new constellation. Regenerates.
    var seed: Int = 1

    // MARK: Earth scene
    /// Multiplier on `EarthSceneView`'s halo/cradle backdrop gradients so
    /// the cream-era bloom doesn't wash the dark sky. 1 = shipped look.
    var earthBackdropDim: Float = 0.25
  }

  var values = Values()

  func reset() { values = Values() }
}

// MARK: - Star field

/// Everything baked at generation time; the tuning sliders scale these unit
/// fractions at draw time, so only `seed` and `starCount` re-roll the field.
struct NightSkyStar {
  var x: Float          // normalized 0...1 across the width
  var y: Float          // normalized 0...1 down the height
  var sizeT: Float      // 0...1 → lerp(starSizeMin, starSizeMax)
  var brightT: Float    // 0...1 → lerp(brightnessMin, brightnessMax)
  var phase: Float      // 0...2π twinkle phase offset
  var rateJitter: Float // 0.6...1.4 multiplier on twinkleSpeed
  var tintT: Float      // 0...1 position on the cream→cool ramp
  var twinkleT: Float   // compared against twinkleShare at draw time
}

/// Deterministic star generation with a single-entry memo. The memo is not
/// observable state on purpose: it's written during view update (from `body`),
/// which is safe precisely because nothing invalidates on it.
@MainActor
enum NightSkyStarField {
  private static var memo: (seed: Int, count: Int, stars: [NightSkyStar])?

  static func stars(seed: Int, count: Int) -> [NightSkyStar] {
    if let memo, memo.seed == seed, memo.count == count { return memo.stars }
    var rng = SplitMix64(state: UInt64(bitPattern: Int64(seed)) &+ 0x5EED)
    let stars = (0..<count).map { _ in
      NightSkyStar(
        x: rng.unit(),
        y: rng.unit(),
        sizeT: rng.unit(),
        brightT: rng.unit(),
        phase: rng.unit() * 2 * .pi,
        rateJitter: 0.6 + rng.unit() * 0.8,
        tintT: rng.unit(),
        twinkleT: rng.unit()
      )
    }
    memo = (seed, count, stars)
    return stars
  }
}

/// Seeded generator (SplitMix64) — tiny, allocation-free, and stable across
/// runs, so a seed value always reproduces the same constellation.
private struct SplitMix64 {
  var state: UInt64

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  /// Uniform in [0, 1) from the top 24 bits.
  mutating func unit() -> Float { Float(next() >> 40) / Float(1 << 24) }
}

// MARK: - View

/// Night starry backdrop for the Earth orb: a dark plum gradient, a soft
/// horizon glow, and a seeded field of twinkling stars. Every visual knob
/// lives in `NightSkyTuning`, the single source of the shipped look.
struct NightSkyBackground: View {
  let tuning: NightSkyTuning
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    // Snapshot values and stars here in body — this registers the @Observable
    // dependencies and keeps the Canvas draw closure pure.
    let v = tuning.values
    let stars = NightSkyStarField.stars(seed: v.seed, count: v.starCount)
    let twinklePaused = reduceMotion || v.twinkleDepth <= 0 || v.twinkleShare <= 0
    ZStack {
      // Gradients live as ZStack siblings, not inside the Canvas — they only
      // change when a slider moves, so the 30fps timeline never re-rasterizes
      // them.
      LinearGradient(
        colors: [
          Self.skyColor(darkness: v.skyTopDarkness),
          Self.skyColor(darkness: v.skyBottomDarkness)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      EllipticalGradient(
        colors: [Color.softLilac.opacity(Double(v.horizonGlow)), .clear],
        center: UnitPoint(x: 0.5, y: 1.1),
        startRadiusFraction: 0,
        endRadiusFraction: 0.8
      )
      TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: twinklePaused)) { context in
        // The timeline only drives invalidation; time comes from the
        // CACurrentMediaTime clock (EarthHaloRipples convention).
        let _ = context.date
        let now = CACurrentMediaTime()
        Canvas { ctx, size in
          Self.drawStars(
            ctx: ctx, size: size, stars: stars, values: v,
            now: now, twinkling: !twinklePaused
          )
        }
      }
    }
    .allowsHitTesting(false)
  }

  /// Lerp between the twilight plum (DuskAtmosphereBackground's lightest
  /// stop) and a near-black plum. Raw RGB on purpose — these are night-only
  /// shades between tokens, same precedent as DuskAtmosphereBackground.
  private static func skyColor(darkness: Float) -> Color {
    let t = min(max(darkness, 0), 1)
    return Color(
      red: Double(mixF(0.24, 0.04, t)),
      green: Double(mixF(0.20, 0.03, t)),
      blue: Double(mixF(0.36, 0.10, t))
    )
  }

  private static func drawStars(
    ctx: GraphicsContext,
    size: CGSize,
    stars: [NightSkyStar],
    values v: NightSkyTuning.Values,
    now: TimeInterval,
    twinkling: Bool
  ) {
    guard !stars.isEmpty else { return }

    // Sliders allow min > max — clamp at draw time instead of fighting the UI.
    let sizeLo = min(v.starSizeMin, v.starSizeMax)
    let sizeHi = max(v.starSizeMin, v.starSizeMax)
    let brightLo = min(v.brightnessMin, v.brightnessMax)
    let brightHi = max(v.brightnessMin, v.brightnessMax)

    // Tint endpoints once per frame. Raw token RGB (moonCream, skyWash,
    // lavenderMist) because per-channel lerping needs components — the
    // authoritative values live in DeepTheme's palette.
    let cream: (Float, Float, Float) = (0.984, 0.969, 1.0)
    let sky: (Float, Float, Float) = (0.773, 0.847, 0.941)
    let lavender: (Float, Float, Float) = (0.722, 0.655, 0.910)
    let cool = (
      mixF(sky.0, lavender.0, v.tintBalance),
      mixF(sky.1, lavender.1, v.tintBalance),
      mixF(sky.2, lavender.2, v.tintBalance)
    )

    // Wrap the clock daily so Float keeps sub-frame precision on long uptimes;
    // the once-a-day phase jump is invisible in practice.
    let t = Float(now.truncatingRemainder(dividingBy: 86_400))
    let drawHalo = v.glowScale > 1 && v.glowAlpha > 0

    for star in stars {
      let twinkles = star.twinkleT < v.twinkleShare
      let osc: Float
      if twinkling && twinkles {
        let angle = t * 2 * .pi * v.twinkleSpeed * star.rateJitter + star.phase
        osc = 1 - v.twinkleDepth * (0.5 + 0.5 * sin(angle))
      } else {
        // Paused (reduce-motion or zeroed twinkle): rest at mid-brightness.
        osc = 1 - (twinkles ? v.twinkleDepth * 0.5 : 0)
      }
      let fade = v.horizonFade > 0
        ? 1 - smoothstepF(1 - v.horizonFade, 1, star.y)
        : 1
      let alpha = mixF(brightLo, brightHi, star.brightT) * osc * fade
      guard alpha > 0.004 else { continue }

      let tintAmount = star.tintT * v.tintSpread
      let tint = Color(
        red: Double(mixF(cream.0, cool.0, tintAmount)),
        green: Double(mixF(cream.1, cool.1, tintAmount)),
        blue: Double(mixF(cream.2, cool.2, tintAmount))
      )

      let center = CGPoint(
        x: CGFloat(star.x) * size.width,
        y: CGFloat(star.y) * size.height
      )
      let radius = CGFloat(mixF(sizeLo, sizeHi, star.sizeT))

      if drawHalo {
        let haloRadius = radius * CGFloat(v.glowScale)
        let haloRect = CGRect(
          x: center.x - haloRadius,
          y: center.y - haloRadius,
          width: haloRadius * 2,
          height: haloRadius * 2
        )
        ctx.fill(
          Path(ellipseIn: haloRect),
          with: .radialGradient(
            Gradient(colors: [tint.opacity(Double(alpha * v.glowAlpha)), .clear]),
            center: center,
            startRadius: 0,
            endRadius: haloRadius
          )
        )
      }

      let coreRect = CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
      )
      ctx.fill(Path(ellipseIn: coreRect), with: .color(tint.opacity(Double(alpha))))
    }
  }
}

// MARK: - Local math helpers

private func mixF(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }
private func smoothstepF(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
  let t = max(0, min(1, (x - e0) / (e1 - e0)))
  return t * t * (3 - 2 * t)
}

#Preview("Night sky") {
  // Hermetic: fresh tuning, never the shared singleton.
  NightSkyBackground(tuning: NightSkyTuning())
    .ignoresSafeArea()
}

#Preview("Night sky — dense, heavy twinkle") {
  let tuning = NightSkyTuning()
  tuning.values.starCount = 250
  tuning.values.twinkleDepth = 0.9
  tuning.values.twinkleShare = 1.0
  return NightSkyBackground(tuning: tuning)
    .ignoresSafeArea()
}
