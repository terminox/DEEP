import SwiftUI

/// Deep's loading indicator: a softly pulsing orb — never a spinner or
/// skeleton-shimmer (DESIGN.md forbids those). Used for network waits and the
/// launch session-restore. Honours Reduce Motion by holding still.
struct LoadingOrb: View {
  var message: String? = nil

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pulsing = false

  var body: some View {
    VStack(spacing: .rhythm) {
      ZStack {
        Circle()
          .fill(
            RadialGradient(
              colors: [.white.opacity(0.9), Color.lavenderMist.opacity(0.5), .clear],
              center: .center, startRadius: 2, endRadius: 60
            )
          )
          .frame(width: 120, height: 120)
          .scaleEffect(pulsing ? 1.08 : 0.92)
          .opacity(pulsing ? 1.0 : 0.7)

        Circle()
          .strokeBorder(.white.opacity(0.6), lineWidth: 1)
          .frame(width: 84, height: 84)
          .scaleEffect(pulsing ? 1.05 : 0.95)
      }
      .accessibilityHidden(true)

      if let message {
        Text(message)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .multilineTextAlignment(.center)
      }
    }
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
        pulsing = true
      }
    }
  }
}

#Preview("Loading orb") {
  ZStack {
    AtmosphereBackground()
    LoadingOrb(message: "Finding your calm…")
  }
}
