import SwiftUI

/// Dusk twilight variant of the atmosphere — used only during an active
/// Global Pause session. Deep Plum base with lavender + blush ambient orbs,
/// so the dotted world map can glow against it. Same palette as the daytime
/// atmosphere, weight inverted.
struct DuskAtmosphereBackground: View {
  @State private var drift = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.12, green: 0.10, blue: 0.20),
          Color(red: 0.18, green: 0.15, blue: 0.28),
          Color(red: 0.24, green: 0.20, blue: 0.36),
          Color(red: 0.30, green: 0.24, blue: 0.40)
        ],
        startPoint: .top,
        endPoint: .bottom
      )

      orb(color: .lavenderMist, size: 320, opacity: 0.30)
        .offset(x: drift ? -110 : -150, y: drift ? -300 : -260)
        .blur(radius: 90)

      orb(color: .blushPowder, size: 260, opacity: 0.22)
        .offset(x: drift ? 150 : 120, y: drift ? -200 : -240)
        .blur(radius: 100)

      orb(color: .skyWash, size: 220, opacity: 0.18)
        .offset(x: drift ? -140 : -110, y: drift ? 360 : 320)
        .blur(radius: 90)

      orb(color: .peachCloud, size: 180, opacity: 0.14)
        .offset(x: drift ? 160 : 140, y: drift ? 280 : 320)
        .blur(radius: 80)
    }
    .ignoresSafeArea()
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
        drift.toggle()
      }
    }
  }

  private func orb(color: Color, size: CGFloat, opacity: Double) -> some View {
    Circle()
      .fill(color.opacity(opacity))
      .frame(width: size, height: size)
  }
}

#Preview {
  DuskAtmosphereBackground()
}
