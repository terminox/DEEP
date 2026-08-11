import SwiftUI

/// The little live badge for Fuku's Lounge — a softly pulsing dot beside
/// "ON AIR" in the `FeatureCard` duration-pill recipe. The pulse breathes on
/// the `.exhale` curve and holds still under Reduce Motion.
struct OnAirPill: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dotDimmed = false

  var body: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(.blushPowder)
        .frame(width: 6, height: 6)
        .opacity(dotDimmed ? 0.4 : 1)
        .accessibilityHidden(true)

      Text("ON AIR")
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.deepPlum)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 5)
    .background(.white.opacity(0.5), in: Capsule())
    .accessibilityLabel("On air")
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.exhale.repeatForever(autoreverses: true)) {
        dotDimmed = true
      }
    }
  }
}

#Preview("On air pill") {
  ZStack {
    AtmosphereBackground()
    OnAirPill()
  }
}
