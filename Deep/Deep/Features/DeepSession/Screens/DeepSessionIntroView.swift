import SwiftUI

/// The threshold before a Deep Session — a quiet page that shows what the
/// practice holds (pattern, length) and offers one way in. Pushed onto the
/// launching tab's navigation (so the tab bar and mini player stay), where
/// Begin lifts the practice up over the whole shell.
///
/// Navigation chrome is the system's: a back chevron over a hidden bar
/// background, and the edge-swipe pop that comes with it. A custom close
/// control would cost the gesture — UIKit ties the interactive pop to the
/// system back button, and no delegate trick restores it once that button is
/// gone (verified on both a SwiftUI `NavigationStack` and a UIKit one).
///
/// Leaf screen, so it owns its screen-level styling (per the coordinator
/// rules).
struct DeepSessionIntroView: View {
  let session: DeepSession

  /// A slow idle drift so the orb already breathes while you decide.
  @State private var swell: CGFloat = 0.5
  /// True from Begin until the practice closes — the beat this screen answers
  /// with its own half of the lift.
  @State private var isRunning = false

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
      .offset(y: contentLift)
    }
    // This screen's half of the lift: the content rises as the practice fades
    // up over it. Only the content — the `moonCream` base and the atmosphere
    // stay anchored, so no gap can open at an edge — and no opacity, since the
    // practice's own opaque base already fades this out at exactly the right
    // rate.
    .animation(.hush, value: isRunning)
    .deepSessionRun(session: session, isPresented: $isRunning)
    // The bar stays but disappears: no title (the practice already names itself
    // in the middle of the screen) and no background, so the atmosphere runs
    // under the chevron.
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .onAppear {
      withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
        swell = 0.7
      }
    }
  }

  /// Matches `SoftDrift.drop`, the travel the practice's own stages use.
  private var contentLift: CGFloat {
    isRunning && !reduceMotion ? -16 : 0
  }

  private var beginButton: some View {
    Button {
      isRunning = true
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
  // Inside a stack, the way it is really reached — pushed from an entry card.
  NavigationStack {
    DeepSessionIntroView(session: DeepSessionLibrary.balancingBreath)
  }
  .environment(\.soundPlayer, MockSoundPlayer.idle)
  .environment(\.practiceStore, MockPracticeStore())
  .environment(\.heartLedger, .sample)
}
