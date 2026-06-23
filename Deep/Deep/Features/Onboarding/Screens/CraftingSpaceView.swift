import SwiftUI

/// A gentle loading beat after the quiz: a short checklist ticks itself off,
/// then the flow drifts on to the rhythm picker. No progress %, no urgency —
/// just a breath. Adapted from the Calm reference's "We're crafting your sleep
/// plan" screen.
struct CraftingSpaceView: View {
  @Environment(\.onboardingAdvance) private var advance
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let steps = [
    "Gathering a little calm",
    "Listening to what you shared",
    "Choosing sounds that suit you",
    "Shaping your space",
    "Almost ready",
  ]

  @State private var completedCount = 0

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(alignment: .leading, spacing: .rhythm) {
        Text("We're shaping your space")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .padding(.top, 8)

        VStack(alignment: .leading, spacing: 20) {
          ForEach(Array(steps.enumerated()), id: \.offset) { offset, step in
            CraftingChecklistRow(title: step, isDone: offset < completedCount)
          }
        }

        Spacer()
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationBarBackButtonHidden(true)
    .task { await runSequence() }
  }

  private func runSequence() async {
    let stepDelay: UInt64 = reduceMotion ? 250_000_000 : 520_000_000 // ns
    for step in 1...steps.count {
      try? await Task.sleep(nanoseconds: stepDelay)
      withAnimation(.bloom) { completedCount = step }
    }
    try? await Task.sleep(nanoseconds: 450_000_000)
    advance(.rhythmPicker)
  }
}

#Preview("Onboarding — Crafting") {
  CraftingSpaceView()
}
