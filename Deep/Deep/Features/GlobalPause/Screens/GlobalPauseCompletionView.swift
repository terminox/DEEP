import SwiftUI

/// Conducts the end of a Global Pause night: the reflection the member takes
/// part in, then the reward ritual it earned. The order matters — the first
/// peace message of the night earns its own hearts and sunlight, so the ritual
/// is composed only once the composer has had its say and can total the whole
/// night in one breath.
///
/// Both steps sit inside the session controller's single hosting controller, so
/// the globe's silent handback behind the opaque reflection is untouched.
struct GlobalPauseCompletionView: View {
  /// The books as they stood when the meditation ended, frozen before the
  /// attendance claim went out.
  let before: GlobalPauseRewardSnapshot
  var onFinish: () -> Void = {}

  @Environment(\.globalPauseSession) private var session
  @Environment(\.heartLedger) private var heartLedger
  @Environment(\.gardenStore) private var gardenStore
  @Environment(\.practiceStore) private var practiceStore

  /// Nil until the member leaves the reflection; setting it is what moves the
  /// ending on, so the ritual can never render on unsettled figures.
  @State private var receipt: RewardReceipt?
  @State private var isPreparing = false

  var body: some View {
    ZStack {
      // One atmosphere for the whole ending. Held here rather than inside each
      // half so the reflection → ritual crossfade never dissolves two
      // independently drifting copies of it into each other. `veils: false`
      // for the same family of reason: `SoftDriftTransition` clips
      // `AtmosphereBackground`'s blurred orbs into hard discs if it rasterizes
      // them under an animated blur.
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()

      if let receipt {
        RewardRitualView(
          receipt: receipt,
          paintsBackground: false,
          onFinish: onFinish
        )
        .transition(.softDrift(veils: false))
      } else {
        GlobalPauseReflectionView(isPreparing: isPreparing) {
          Task { await showRewards() }
        }
        .transition(.softDrift(veils: false))
      }
    }
  }

  /// Lets any claim still in flight land — and the practice journal hydrate,
  /// so the rhythm is the account's real one — then freezes the night into one
  /// receipt. The stores have already absorbed both grants through the shared
  /// award sink (and a counted pause has already marked the day), so "after"
  /// is simply what they now hold.
  private func showRewards() async {
    guard receipt == nil, !isPreparing else { return }
    isPreparing = true
    async let settled: Void = session.settlePauseAward()
    async let hydrated: Void = practiceStore.awaitHydration(timeout: .seconds(2))
    _ = await (settled, hydrated)
    let composed = compose()
    withAnimation(.hush) { receipt = composed }
  }

  private func compose() -> RewardReceipt {
    RewardReceipt(
      pauseNight: before,
      awards: [session.pauseAward, session.messageAward].compactMap { $0 },
      gardenAfter: gardenStore.growth,
      heartBalanceAfter: heartLedger.balance,
      heartsEarnedTodayAfter: heartLedger.heartsEarnedToday,
      continuity: practiceStore.continuityTransition(),
      continuityKnown: practiceStore.isHydrated,
      attendanceMissed: session.pauseAwardMissed,
      attendancePending: session.pauseAwardPending
    )
  }
}

#if DEBUG
#Preview("Pause ending") {
  GlobalPauseCompletionView(before: .sample)
    .environment(\.globalPauseSession, .previewAwarded())
    .environment(\.heartLedger, .sample)
    .environment(\.gardenStore, .sample)
    .environment(\.practiceStore, MockPracticeStore(practicedToday: true))
    .environment(\.continuityWitness, .unwitnessed)
}

#Preview("Pause ending — rhythm already witnessed") {
  GlobalPauseCompletionView(before: .rhythmWitnessed)
    .environment(\.globalPauseSession, .previewAwarded())
    .environment(\.heartLedger, .sample)
    .environment(\.gardenStore, .sample)
    .environment(\.practiceStore, MockPracticeStore(practicedToday: true))
    .environment(\.continuityWitness, .witnessed)
}

#Preview("Pause ending — claim still on its way") {
  GlobalPauseCompletionView(before: .sample)
    .environment(\.globalPauseSession, .previewPending())
    .environment(\.heartLedger, .sample)
    .environment(\.gardenStore, .sample)
    .environment(\.practiceStore, MockPracticeStore())
    .environment(\.continuityWitness, .unwitnessed)
}

#Preview("Pause ending — attendance missed") {
  GlobalPauseCompletionView(before: .sample)
    .environment(\.globalPauseSession, .previewMissed())
    .environment(\.heartLedger, .sample)
    .environment(\.gardenStore, .sample)
    .environment(\.practiceStore, MockPracticeStore())
    .environment(\.continuityWitness, .unwitnessed)
}
#endif
