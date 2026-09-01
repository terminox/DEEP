import SwiftUI

struct AtmosphereBackground: View {
  /// One ambient orb's spec. Hoisted out of `body` because the OS launch screen
  /// ships this same atmosphere as flat stills — a launch screen runs no code —
  /// and those stills have to land on the resting offsets pixel-for-pixel, or
  /// the hand-off from the launch screen into SwiftUI shows a jump. One
  /// declaration, two consumers: this view and `LaunchAtmosphereExportTests`.
  struct Orb {
    let color: Color
    let size: CGFloat
    let blur: CGFloat
    /// Where the orb sits at rest — the app's first frame, and so the launch
    /// screen's.
    let rest: CGSize
    /// The far end of the ambient drift.
    let drifted: CGSize

    /// The orb's artwork, without its placement or blur.
    var artwork: some View {
      Circle()
        .fill(color.opacity(0.55))
        .frame(width: size, height: size)
    }

    /// The resting orb, blurred and centred on a canvas wide enough that the
    /// gaussian tail is never clipped — what the launch screen ships as a still.
    var still: some View {
      artwork
        .blur(radius: blur)
        .frame(width: canvas, height: canvas)
    }

    /// The still's canvas. Eight blur radii of margin puts the edge well beyond
    /// the gaussian's ~3σ tail, so no light is cut off.
    var canvas: CGFloat { size + 8 * blur }
  }

  /// Back to front — the array's order is the ZStack's z-order.
  static let orbs: [Orb] = [
    Orb(
      color: .lavenderMist, size: 220, blur: 60,
      rest: CGSize(width: -120, height: -240), drifted: CGSize(width: -90, height: -260)
    ),
    Orb(
      color: .blushPowder, size: 180, blur: 70,
      rest: CGSize(width: 110, height: -210), drifted: CGSize(width: 130, height: -180)
    ),
    Orb(
      color: .skyWash, size: 160, blur: 60,
      rest: CGSize(width: -100, height: 300), drifted: CGSize(width: -120, height: 320)
    )
  ]

  /// The sky wash. Its lower stops are translucent by design — the atmosphere is
  /// always composited over `.moonCream` (see `AppRootView`), so anything that
  /// flattens this gradient has to lay it over moonCream first.
  static let sky = LinearGradient(
    colors: [
      .moonCream,
      Color.softLilac.opacity(0.55),
      Color.blushPowder.opacity(0.45),
      Color.peachCloud.opacity(0.30)
    ],
    startPoint: .top,
    endPoint: .bottom
  )

  /// Set false where the atmosphere must hold still — e.g. inside the ripple
  /// overlay's freeze-frame, where an animating subtree would force the layer
  /// effect to re-rasterize the blurred orbs every frame. May change while on
  /// screen; the drift settles or resumes to match.
  var animated = true

  @State private var drift = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      Self.sky

      // Ambient floating orbs.
      ForEach(Array(Self.orbs.enumerated()), id: \.offset) { _, orb in
        let offset = drift ? orb.drifted : orb.rest
        orb.artwork
          .offset(x: offset.width, y: offset.height)
          .blur(radius: orb.blur)
      }
    }
    .ignoresSafeArea()
    .onAppear { updateDrift() }
    .onChange(of: animated) { updateDrift() }
  }

  /// Starts or stops the ambient drift to match `animated`. Stopping replaces
  /// the in-flight `repeatForever` with a short settle back to rest, so Core
  /// Animation stops invalidating the blurred orbs once they land.
  private func updateDrift() {
    if animated, !reduceMotion {
      withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
        drift.toggle()
      }
    } else {
      withAnimation(.easeInOut(duration: 2)) { drift = false }
    }
  }
}

#Preview {
  AtmosphereBackground()
}

#Preview("Static") {
  AtmosphereBackground(animated: false)
}
