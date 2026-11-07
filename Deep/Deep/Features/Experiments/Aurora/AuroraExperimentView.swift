#if EXPERIMENTS
import SwiftUI

// Settings → Experiments → Aurora: the night sky over the hills of northern
// Thailand, with aurora curtains that move with a simulated meditator's brain.
// A pure picture: no captions, no controls beyond a close button that fades
// away. The sit loops until the person leaves. This is the one screen in DEEP
// that may turn landscape (see `OrientationLock`).
//
// The sky is one Metal colour effect (`EEGAurora.metal`); the hills and the sea
// of mist in front of it are Canvas paths. Data → sky (all smoothed first so
// nothing jumps):
// - alpha → green curtain strength      - theta → violet / magenta upper fringe
// - beta  → warm pink lower edge, faster and choppier folds
// - gamma → small sparkles (a jaw clench flares them)
// - calm (DEEP's alpha/beta index) → taller, slower, smoother curtains
// - blink → a soft shimmer travelling along the curtain
// - heart rate → the slow swell of the whole aurora's brightness
// - stillness → clearer, steadier stars
// Origin: variant C of the EEG art prototype (`prototype/eeg-art` branch).

// MARK: - Palette (experiment-local source of truth)

private struct AuroraColorToken {
  let red: Double
  let green: Double
  let blue: Double
  var color: Color { Color(red: red, green: green, blue: blue) }
}

private enum AuroraPalette {
  static let ridgeFar = AuroraColorToken(red: 0.040, green: 0.050, blue: 0.110)
  static let ridgeFarHaze = AuroraColorToken(red: 0.085, green: 0.105, blue: 0.190)
  static let ridgeMid = AuroraColorToken(red: 0.022, green: 0.028, blue: 0.068)
  static let ridgeNear = AuroraColorToken(red: 0.008, green: 0.010, blue: 0.026)
  static let mist = AuroraColorToken(red: 0.560, green: 0.620, blue: 0.780)
  static let curtainGreen = AuroraColorToken(red: 0.300, green: 0.950, blue: 0.620)
  static let curtainViolet = AuroraColorToken(red: 0.600, green: 0.380, blue: 0.980)
  static let nightInk = AuroraColorToken(red: 0.020, green: 0.026, blue: 0.070)
}

// MARK: - The sky's inputs

/// Everything one frame of the sky needs, smoothed and integrated. A plain
/// value, so a frozen copy renders the exact same picture for export.
private struct AuroraState: Equatable {
  var time: Double = 0
  var phase: Double = 0
  var alpha: Double = 0
  var theta: Double = 0
  var beta: Double = 0
  var gamma: Double = 0
  var calm: Double = 0
  var stillness: Double = 0
  var breath: Double = 0
  var shimmerX: Double = 0
  var shimmer: Double = 0
}

/// The raw targets read from one EEG frame, normalised against the ranges the
/// simulated Muse 2 produces across the three people.
private struct AuroraTargets {
  var alpha: Double
  var theta: Double
  var beta: Double
  var gamma: Double
  var calm: Double
  var stillness: Double
  var heartRate: Double

  init(_ frame: EEGFrame) {
    alpha = Self.ramp(0.14, 0.42, frame.relative.alpha)
    theta = Self.ramp(0.17, 0.36, frame.relative.theta)
    beta = Self.ramp(0.05, 0.30, frame.relative.beta)
    gamma = Self.ramp(0.03, 0.11, frame.relative.gamma)
    // Our calm index spans ~0.15 (first time) to ~0.85 (experienced), never 1.
    calm = min(max((frame.calm - 0.10) / 0.75, 0), 1)
    stillness = frame.stillness
    heartRate = frame.heartRate
  }

  private static func ramp(_ low: Double, _ high: Double, _ value: Double) -> Double {
    let t = min(max((value - low) / (high - low), 0), 1)
    return t * t * (3 - 2 * t)
  }
}

/// Turns a stream of frames into a calm sky. Not observed: it is advanced from
/// inside the TimelineView once per display frame and only carries memory
/// (smoothing, the fold clock, the breath, the current shimmer).
private final class AuroraDriver {
  private let start = Date.timeIntervalSinceReferenceDate
  private var last: Double?
  private var state = AuroraState()
  private var heartRate = 70.0
  private var shimmerStart = -100.0
  private var breathPhase = 0.0
  private static let shimmerLength = 2.2

  /// - Parameters:
  ///   - blinkWall: wall seconds of the latest blink, if any.
  ///   - smoothing: seconds for the inputs to settle toward a new frame.
  func advance(wall: Double, frame: EEGFrame, blinkWall: Double?, smoothing: Double) -> AuroraState {
    let target = AuroraTargets(frame)
    let dt = last.map { min(max(wall - $0, 0), 0.1) } ?? 0
    if last == nil {
      state.alpha = target.alpha
      state.theta = target.theta
      state.beta = target.beta
      state.gamma = target.gamma
      state.calm = target.calm
      state.stillness = target.stillness
      heartRate = target.heartRate
    } else {
      let k = 1 - exp(-dt / smoothing)
      state.alpha += (target.alpha - state.alpha) * k
      state.theta += (target.theta - state.theta) * k
      state.beta += (target.beta - state.beta) * k
      // Sparkles may flare quicker than the curtain changes.
      state.gamma += (target.gamma - state.gamma) * min(k * 2.5, 1)
      state.calm += (target.calm - state.calm) * k
      state.stillness += (target.stillness - state.stillness) * k
      heartRate += (target.heartRate - heartRate) * k
    }
    last = wall

    // The fold clock: speed × dt, so a change of tempo never lurches the folds.
    let speed = 0.2 + 0.6 * (1 - state.calm) + 0.4 * state.beta
    state.phase += speed * dt

    // One slow swell every five heartbeats.
    breathPhase += dt * 2 * .pi * (heartRate / 60) / 5
    state.breath = sin(breathPhase)

    // A blink starts a shimmer unless one is still travelling.
    if let blinkWall, wall - blinkWall < 0.6, blinkWall > shimmerStart + Self.shimmerLength * 0.8 {
      shimmerStart = blinkWall
    }
    let age = (wall - shimmerStart) / Self.shimmerLength
    if age >= 0, age <= 1 {
      state.shimmerX = age
      state.shimmer = sin(.pi * age) * 0.9
    } else {
      state.shimmer = 0
    }

    state.time = wall - start
    return state
  }
}

// MARK: - The screen

struct AuroraExperimentView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var player = EEGSessionPlayer(recording: .regular)
  @State private var driver = AuroraDriver()
  @State private var showsClose = true
  @State private var hideClose: Task<Void, Never>?

  var body: some View {
    TimelineView(.animation) { context in
      let wall = context.date.timeIntervalSinceReferenceDate
      let frame = player.frame(at: context.date)
      let blink = player.liveArtifacts.last { $0.kind == .blink }?.wallTime
      AuroraScene(state: driver.advance(wall: wall, frame: frame, blinkWall: blink, smoothing: 1.2))
    }
    .ignoresSafeArea()
    .contentShape(Rectangle())
    .onTapGesture(perform: revealClose)
    .overlay(alignment: .topLeading) {
      if showsClose {
        Button("Close", systemImage: "xmark") { dismiss() }
          .labelStyle(.iconOnly)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.moonCream)
          .frame(width: 44, height: 44)
          .background(.ultraThinMaterial, in: Circle())
          .padding(.leading, .edge)
          .padding(.top, 8)
          .transition(.opacity)
          .accessibilityIdentifier("aurora.close")
      }
    }
    .statusBarHidden()
    .persistentSystemOverlays(.hidden)
    .preferredColorScheme(.dark)
    .onAppear {
      OrientationLock.allow(.allButUpsideDown)
      UIApplication.shared.isIdleTimerDisabled = true
      player.start()
      revealClose()
    }
    .onDisappear {
      player.stop()
      hideClose?.cancel()
      UIApplication.shared.isIdleTimerDisabled = false
      OrientationLock.allow(.portrait)
    }
  }

  /// Shows the close button, then lets it fade after three seconds.
  private func revealClose() {
    withAnimation(.settle) { showsClose = true }
    hideClose?.cancel()
    hideClose = Task {
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      withAnimation(.hush) { showsClose = false }
    }
  }
}

// MARK: - The scene

/// Where the hills begin, as a fraction of the height. The shader keeps the
/// curtains above it.
private let auroraHorizon = 0.72

/// The sky shader with the hills and mist in front of it.
private struct AuroraScene: View {
  let state: AuroraState

  var body: some View {
    ZStack {
      Rectangle()
        .visualEffect { [state, horizon = auroraHorizon] content, proxy in
          content.colorEffect(
            ShaderLibrary.eegAurora(
              .float2(proxy.size),
              .float(Float(state.time.truncatingRemainder(dividingBy: 3600))),
              .float(Float(state.phase)),
              .float(Float(state.alpha)),
              .float(Float(state.theta)),
              .float(Float(state.beta)),
              .float(Float(state.gamma)),
              .float(Float(state.calm)),
              .float(Float(state.stillness)),
              .float(Float(state.breath)),
              .float(Float(state.shimmerX)),
              .float(Float(state.shimmer)),
              .float(Float(horizon))
            )
          )
        }
      AuroraHills(time: state.time, glow: state.alpha, violet: state.theta)
    }
  }
}

/// Three soft ridges (Doi Inthanon's broad summit on the far one) with a sea
/// of mist between them, lit faintly by the aurora.
private struct AuroraHills: View {
  let time: Double
  let glow: Double
  let violet: Double

  private struct Ridge {
    let base: Double
    let amplitude: Double
    let scale: Double
    let seed: UInt64
    /// A broad summit: centre, width, height (fractions).
    var summit: (Double, Double, Double)?

    func y(_ u: Double) -> Double {
      func n(_ x: Double, _ s: UInt64) -> Double { (eegNoise(x, seed: s) + 1) / 2 }
      var height = 0.55 * n(u * scale, seed)
        + 0.30 * n(u * scale * 2.7 + 4, seed &+ 1)
        + 0.15 * n(u * scale * 7.1 + 9, seed &+ 2)
      height *= amplitude
      if let summit {
        let d = (u - summit.0) / summit.1
        height += summit.2 * exp(-d * d)
      }
      return base - height
    }

    func path(in size: CGSize) -> Path {
      Path { path in
        let steps = 90
        path.move(to: CGPoint(x: 0, y: size.height))
        for step in 0...steps {
          let u = Double(step) / Double(steps)
          path.addLine(to: CGPoint(x: u * size.width, y: y(u) * size.height))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
      }
    }
  }

  private static let far = Ridge(base: 0.765, amplitude: 0.055, scale: 2.1, seed: 41, summit: (0.66, 0.24, 0.05))
  private static let mid = Ridge(base: 0.815, amplitude: 0.05, scale: 2.8, seed: 53)
  private static let near = Ridge(base: 0.885, amplitude: 0.055, scale: 1.9, seed: 67)

  var body: some View {
    Canvas { context, size in
      let h = size.height
      let auroraTint = AuroraPalette.curtainGreen.color.opacity(0.16 + 0.22 * glow)

      // Aurora light pooling on the far summit line.
      let far = Self.far.path(in: size)
      context.fill(far, with: .linearGradient(
        Gradient(colors: [AuroraPalette.ridgeFar.color, AuroraPalette.ridgeFarHaze.color]),
        startPoint: CGPoint(x: 0, y: 0.68 * h),
        endPoint: CGPoint(x: 0, y: 0.80 * h)
      ))
      context.stroke(far, with: .color(auroraTint), lineWidth: 0.8)

      mist(in: &context, size: size, centre: 0.775, depth: 0.05, drift: 0.006, opacity: 0.12)

      let mid = Self.mid.path(in: size)
      context.fill(mid, with: .linearGradient(
        Gradient(colors: [AuroraPalette.ridgeMid.color, AuroraPalette.ridgeFar.color]),
        startPoint: CGPoint(x: 0, y: 0.74 * h),
        endPoint: CGPoint(x: 0, y: 0.86 * h)
      ))
      context.stroke(mid, with: .color(AuroraPalette.curtainGreen.color.opacity(0.05 + 0.08 * glow)), lineWidth: 0.6)

      mist(in: &context, size: size, centre: 0.845, depth: 0.04, drift: -0.004, opacity: 0.08)

      context.fill(Self.near.path(in: size), with: .color(AuroraPalette.ridgeNear.color))
    }
    .allowsHitTesting(false)
  }

  /// A drifting band of valley mist, tinted by the aurora above it.
  private func mist(in context: inout GraphicsContext, size: CGSize, centre: Double, depth: Double, drift: Double, opacity: Double) {
    let w = size.width
    let h = size.height
    let base = AuroraPalette.mist
    let green = AuroraPalette.curtainGreen
    let lilac = AuroraPalette.curtainViolet
    let g = 0.22 * glow
    let v = 0.15 * violet
    let mistColor = Color(
      red: base.red * (1 - g - v) + green.red * g + lilac.red * v,
      green: base.green * (1 - g - v) + green.green * g + lilac.green * v,
      blue: base.blue * (1 - g - v) + green.blue * g + lilac.blue * v
    )
    let band = CGRect(x: 0, y: (centre - depth) * h, width: w, height: depth * 2 * h)
    context.fill(Path(band), with: .linearGradient(
      Gradient(stops: [
        .init(color: mistColor.opacity(0), location: 0),
        .init(color: mistColor.opacity(opacity), location: 0.5),
        .init(color: mistColor.opacity(0), location: 1)
      ]),
      startPoint: CGPoint(x: 0, y: band.minY),
      endPoint: CGPoint(x: 0, y: band.maxY)
    ))
    // Slow wisps that wander sideways.
    for index in 0..<3 {
      let u = (Double(index) / 3 + time * drift).truncatingRemainder(dividingBy: 1.2) - 0.1
      let rect = CGRect(x: (u - 0.45) * w, y: (centre - depth * 0.8) * h, width: 0.9 * w, height: depth * 1.6 * h)
      context.fill(Path(ellipseIn: rect), with: .radialGradient(
        Gradient(colors: [mistColor.opacity(opacity * 0.7), mistColor.opacity(0)]),
        center: CGPoint(x: rect.midX, y: rect.midY),
        startRadius: 0,
        endRadius: rect.width / 2
      ))
    }
  }
}

// MARK: - Previews

#Preview("Aurora") {
  AuroraExperimentView()
}

#endif
