import SwiftUI

/// The threshold before a Deep Session — a quiet page that shows what the
/// practice holds (pattern, length) and offers one way in. First stage of the
/// presented flow: `DeepSessionCoordinatorView` shows it full-screen over the
/// shell, Begin crossfades into the session, and the close button dismisses
/// the whole flow.
///
/// Leaf screen, so it owns its screen-level styling (per the coordinator
/// rules).
struct DeepSessionIntroView: View {
  let session: DeepSession
  var onBegin: () -> Void = {}
  var onClose: () -> Void = {}

  /// A slow idle drift so the orb already breathes while you decide.
  @State private var swell: CGFloat = 0.5

  var body: some View {
    ZStack {
      // Opaque base under the atmosphere's translucent stops: nothing beneath
      // this screen may ever show through.
      Color.moonCream.ignoresSafeArea()
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
    .overlay(alignment: .topLeading) {
      GlassCloseButton(action: onClose)
        .padding(.edge)
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
        swell = 0.7
      }
    }
  }

  private var beginButton: some View {
    Button {
      onBegin()
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
  DeepSessionIntroView(session: DeepSessionLibrary.balancingBreath)
}
