import SwiftUI

/// A gentle loading beat after the Mind Tree is chosen: a short checklist
/// ticks itself off, then onboarding finishes and the app crossfades in. No
/// progress %, no urgency — just a breath. Adapted from the Calm reference's
/// "We're crafting your sleep plan" screen.
struct CraftingSpaceView: View {
  @Environment(\.onboardingStore) private var store
  @Environment(\.onboardingRemote) private var remote
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
        }
        .onboardingContentDrift()

        Spacer()
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .task { await runSequence() }
  }

  private func runSequence() async {
    let stepDelay: UInt64 = reduceMotion ? 250_000_000 : 520_000_000 // ns
    for step in 1...steps.count {
      try? await Task.sleep(nanoseconds: stepDelay)
      withAnimation(.bloom) { completedCount = step }
    }
    try? await Task.sleep(nanoseconds: 450_000_000)
    await syncAndFinish()
  }

  /// The loader's real work: push everything onboarding gathered to the backend,
  /// then flip the local completion flag (which opens `AppRootView`'s gate). If
  /// the network is unavailable we still complete locally so the user is never
  /// stranded — the answers persist and can sync later.
  ///
  /// Cancellation is not a network failure: if this view is torn down mid-beat,
  /// the `.task` is cancelled, the sleeps above all return instantly, and the
  /// save's request throws `CancellationError` before it ever leaves the device.
  /// Completing locally then would open the gate *without* the sync — so a
  /// cancelled run simply stops.
  private func syncAndFinish() async {
    guard !Task.isCancelled else { return }
    try? await remote.save(
      quizAnswers: store.state.quizAnswers,
      mindTree: store.state.mindTree,
      completed: true
    )
    guard !Task.isCancelled else { return }
    store.completeOnboarding()
  }
}

#if DEBUG
#Preview("Onboarding — Crafting") {
  CraftingSpaceView()
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
}
#endif
