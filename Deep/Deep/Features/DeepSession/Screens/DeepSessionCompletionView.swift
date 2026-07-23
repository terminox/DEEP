import SwiftUI

/// The gentle beat after a finished Deep Session — what softly grew from the
/// practice: minutes into the garden, a heart earned. Growth reflected back,
/// never a score; no streaks, no goals, no numbers to chase.
///
/// Leaf screen, so it owns its screen-level styling (per the coordinator
/// rules). Third and final stage of the presented flow; Return dismisses it.
struct DeepSessionCompletionView: View {
  var onReturn: () -> Void = {}

  @Environment(\.practiceStore) private var practiceStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The content blooms in from rest once, on arrival.
  @State private var hasArrived = false
  /// One-shot trigger for the earned heart's little flourish.
  @State private var heartFlourish = 0

  var body: some View {
    ZStack {
      // Opaque base under the atmosphere's translucent stops, continuous with
      // the session screen so the crossfade lands on the same sky.
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()

      VStack(spacing: 0) {
        Spacer()

        // The settled orb carries through from the session's final exhale.
        BreathingOrb(swell: 0.6)
          .frame(width: 160)

        grownCard
          .padding(.top, .rhythm * 1.5)

        Spacer()

        returnButton
          .padding(.bottom, .rhythm)
      }
      .padding(.horizontal, .edge)
      .opacity(hasArrived ? 1 : 0)
      .scaleEffect(reduceMotion ? 1 : (hasArrived ? 1 : 0.92))
    }
    .onAppear {
      withAnimation(.bloom) { hasArrived = true }
      heartFlourish += 1
      AccessibilityNotification.Announcement("Session complete. A heart earned.").post()
    }
  }

  // MARK: - What grew

  private var grownCard: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 5) {
        Text("Softly grown")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
        Text("A minute of breathing, settled into your garden.")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      }

      Rectangle()
        .fill(.lavenderMist.opacity(0.22))
        .frame(height: 1)

      grownRow(
        systemImage: "leaf.fill",
        iconStyle: GardenColor.sage,
        text: "\(practiceStore.minutesToday) min in your garden today"
      )

      grownRow(
        systemImage: "heart.fill",
        iconStyle: Color.blushPowder,
        text: "A heart earned, ready to give"
      )
      .heartBurst(trigger: heartFlourish)
    }
    .padding(20)
    .frostedCard()
    .accessibilityElement(children: .combine)
  }

  private func grownRow(systemImage: String, iconStyle: Color, text: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(iconStyle)
        .frame(width: 36, height: 36)
        .background(.white.opacity(0.6), in: Circle())
      Text(text)
        .font(DeepType.body)
        .foregroundStyle(.deepPlum)
      Spacer(minLength: 0)
    }
  }

  // MARK: - Return

  private var returnButton: some View {
    Button {
      onReturn()
    } label: {
      Text("Return")
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
    .accessibilityLabel("Return from your session")
  }
}

#Preview("Deep session — softly grown") {
  DeepSessionCompletionView()
    .environment(\.practiceStore, MockPracticeStore())
}

#Preview("Deep session — first practice") {
  DeepSessionCompletionView()
    .environment(\.practiceStore, MockPracticeStore.fresh)
}
