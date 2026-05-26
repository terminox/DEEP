import SwiftUI

struct AtmosphereBackground: View {
  @State private var drift = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          DeepColor.moonCream,
          DeepColor.softLilac.opacity(0.55),
          DeepColor.blushPowder.opacity(0.45),
          DeepColor.peachCloud.opacity(0.30)
        ],
        startPoint: .top,
        endPoint: .bottom
      )

      // Ambient floating orbs.
      orb(color: DeepColor.lavenderMist, size: 220)
        .offset(x: drift ? -90 : -120, y: drift ? -260 : -240)
        .blur(radius: 60)

      orb(color: DeepColor.blushPowder, size: 180)
        .offset(x: drift ? 130 : 110, y: drift ? -180 : -210)
        .blur(radius: 70)

      orb(color: DeepColor.skyWash, size: 160)
        .offset(x: drift ? -120 : -100, y: drift ? 320 : 300)
        .blur(radius: 60)
    }
    .ignoresSafeArea()
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
        drift.toggle()
      }
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
