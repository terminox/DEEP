import SwiftUI

struct AtmosphereBackground: View {
  /// Set false where the atmosphere must hold still — e.g. inside the ripple
  /// overlay's freeze-frame, where an animating subtree would force the layer
  /// effect to re-rasterize the blurred orbs every frame. May change while on
  /// screen; the drift settles or resumes to match.
  var animated = true

  @State private var drift = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          .moonCream,
          Color.softLilac.opacity(0.55),
          Color.blushPowder.opacity(0.45),
          Color.peachCloud.opacity(0.30)
        ],
        startPoint: .top,
        endPoint: .bottom
      )

      // Ambient floating orbs.
      orb(color: .lavenderMist, size: 220)
        .offset(x: drift ? -90 : -120, y: drift ? -260 : -240)
        .blur(radius: 60)

      orb(color: .blushPowder, size: 180)
        .offset(x: drift ? 130 : 110, y: drift ? -180 : -210)
        .blur(radius: 70)

      orb(color: .skyWash, size: 160)
        .offset(x: drift ? -120 : -100, y: drift ? 320 : 300)
        .blur(radius: 60)
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

  private func orb(color: Color, size: CGFloat) -> some View {
    Circle()
      .fill(color.opacity(0.55))
      .frame(width: size, height: size)
  }
}

#Preview {
  AtmosphereBackground()
}

#Preview("Static") {
  AtmosphereBackground(animated: false)
}
