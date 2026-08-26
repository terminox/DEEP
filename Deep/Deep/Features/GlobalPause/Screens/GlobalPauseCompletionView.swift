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

  /// Nil until the member leaves the reflection; setting it is what moves the
  /// ending on, so the ritual can never render on unsettled figures.
  @State private var receipt: RewardReceipt?
  @State private var isPreparing = false

  var body: some View {
    ZStack {
      if let receipt {
        RewardRitualView(
          receipt: receipt,
          // A pause night adds no practice day, so the beat witnesses the run
          // rather than crediting today.
          continuityHeadline: "Your rhythm continues",
          onFinish: onFinish
        )
        .transition(.softDrift)
      } else {
        GlobalPauseReflectionView(isPreparing: isPreparing) {
          Task { await showRewards() }
        }
        .transition(.softDrift)
      }
    }
  }

  /// Lets any claim still in flight land, then freezes the night into one
  /// receipt. The stores have already absorbed both grants through the shared
  /// award sink, so "after" is simply what they now hold.
  private func showRewards() async {
    guard receipt == nil, !isPreparing else { return }
    isPreparing = true
    await session.settlePauseAward()
    let composed = compose()
    withAnimation(.hush) { receipt = composed }
  }

  private func compose() -> RewardReceipt {
    RewardReceipt(
      pauseNight: before,
      awards: [session.pauseAward, session.messageAward].compactMap { $0 },
      gardenAfter: gardenStore.growth,
      heartBalanceAfter: heartLedger.balance,
      heartsEarnedTodayAfter: heartLedger.heartsEarnedToday
    )
  }
}

#Preview("Pause ending") {
  GlobalPauseCompletionView(before: .sample)
    .environment(\.globalPauseSession, .previewAwarded())
    .environment(\.heartLedger, .sample)
    .environment(\.gardenStore, .sample)
    .environment(\.continuityWitness, .unwitnessed)
}

#Preview("Pause ending — rhythm already witnessed") {
  GlobalPauseCompletionView(before: .rhythmWitnessed)
    .environment(\.globalPauseSession, .previewAwarded())
    .environment(\.heartLedger, .sample)
    .environment(\.gardenStore, .sample)
    .environment(\.continuityWitness, .witnessed)
}
