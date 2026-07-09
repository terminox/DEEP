import SwiftUI

/// The threshold before a Deep Session — a quiet page that shows what the
/// practice holds (pattern, length) and offers one way in. Pushed inside a
/// host feature's navigation stack (e.g. from Deep Sound's Breathe card); the
/// session itself then presents full-screen via `startDeepSession`, and this
/// screen is the natural landing place when it closes.
///
/// Leaf screen, so it owns its screen-level styling (per the coordinator
/// rules).
struct DeepSessionIntroView: View {
  let session: DeepSession

  @Environment(\.startDeepSession) private var startDeepSession

  /// A slow idle drift so the orb already breathes while you decide.
  @State private var swell: CGFloat = 0.5

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(spacing: 0) {
        Spacer()

        BreathingOrb(swell: swell)
          .frame(width: 200)

        VStack(spacing: 8) {
          Text(session.title)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          Text(session.tagline)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .multilineTextAlignment(.center)
        }
        .padding(.top, .rhythm * 1.5)

        VStack(spacing: 4) {
          Text("\(Int(session.inhale))s in · \(Int(session.exhale))s out")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
          Text("\(session.durationMinutes) min · \(session.cycles) rounds")
            .font(DeepType.micro)
            .foregroundStyle(.driftGrey.opacity(0.8))
        }
        .padding(.top, .rhythm)

        Spacer()

        beginButton
          .padding(.bottom, .rhythm)
      }
      .padding(.horizontal, .edge)
    }
    .toolbarBackground(.hidden, for: .navigationBar)
    .onAppear {
      withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
        swell = 0.7
      }
    }
  }

  private var beginButton: some View {
    Button {
      startDeepSession(session)
    } label: {
      Text("Begin")
        .font(DeepType.body.weight(.semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
          Capsule().fill(LinearGradient(
            colors: [.lavenderMist, .softLilac],
            startPoint: .topLeading, endPoint: .bottomTrailing
          ))
        )
        .shadow(color: .lavenderMist.opacity(0.4), radius: 12, x: 0, y: 6)
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("Begin \(session.title)")
  }
}

#Preview("Deep session intro") {
  NavigationStack {
    DeepSessionIntroView(session: DeepSessionLibrary.balancingBreath)
  }
}
