import SwiftUI

/// Composition root for the guided practice — the session itself, then the
/// completion beat, reached on its own once the engine finishes. Presented
/// full-screen over the whole shell (via `deepSessionRun`, from the pushed
/// `DeepSessionIntroView` threshold), so the tab bar and mini player are gone
/// for the duration. Owns the stage switch, the engine, the finish handshake,
/// recording the practice, and silencing the ambient player; all styling lives
/// in the leaf screens (per the coordinator rules).
struct DeepSessionCoordinatorView: View {
  private enum Stage {
    case session
    case completion
  }

  private let session: DeepSession
  /// Ends the practice. The presenter owns the dismissal — SwiftUI's `dismiss`
  /// has no purchase on a UIKit-presented hosting controller — so every way
  /// out routes through here.
  private let onFinish: () -> Void

  @State private var stage: Stage = .session
  @State private var engine: BreathEngine
  /// The completion is credited exactly once, the moment the engine finishes —
  /// so closing from the finished screen still counts.
  @State private var didRecord = false
  /// The immutable before/after truth rendered by the reward sequence.
  @State private var rewardReceipt: RewardReceipt?
  /// Owns the final-exhale hold so dismissal tears it down cleanly.
  @State private var completionTask: Task<Void, Never>?

  @Environment(\.soundPlayer) private var soundPlayer
  @Environment(\.practiceStore) private var practiceStore
  @Environment(\.heartLedger) private var heartLedger
  @Environment(\.gardenStore) private var gardenStore
  @Environment(\.continuityWitness) private var continuityWitness
  @Environment(\.scenePhase) private var scenePhase

  init(session: DeepSession, onFinish: @escaping () -> Void = {}) {
    self.session = session
    self.onFinish = onFinish
    _engine = State(initialValue: BreathEngine(session: session))
  }

  var body: some View {
    ZStack {
      // A soft drift, not a navigation container: the stages only ever
      // move forward (the only way back out is ending the practice), and every
      // screen sits on an opaque base, so the fade can't reveal the threshold
      // beneath.
      switch stage {
      case .session:
        // The view starts the engine itself, after its settling countdown.
        DeepSessionView(
          engine: engine,
          onClose: onFinish
        )
        .transition(.softDrift)
      case .completion:
        if let rewardReceipt {
          RewardRitualView(
            receipt: rewardReceipt,
            continuityHeadline: "You returned today",
            onFinish: onFinish
          )
          .transition(.softDrift)
        }
      }
    }
    .onAppear {
      // A guided breath and ambient audio don't mix — the practice begins in
      // silence. The threshold before it is an ordinary screen in the tab, so
      // the track only stops here. It stays loaded, so the mini player is
      // waiting on return.
      soundPlayer.pause()
      // A breath practice is hands-off; don't let the screen sleep mid-round.
      UIApplication.shared.isIdleTimerDisabled = true
    }
    .onDisappear {
      completionTask?.cancel()
      engine.cancel()
      UIApplication.shared.isIdleTimerDisabled = false
    }
    .onChange(of: engine.phase) { _, phase in
      guard phase == .finished else { return }
      finishSession()
    }
    // Leaving the app settles the practice into a pause; resuming stays the
    // user's own gesture. `.inactive` is deliberately ignored — banners and
    // Control Center shouldn't interrupt a breath.
    .onChange(of: scenePhase) { _, phase in
      guard phase == .background else { return }
      engine.pause()
    }
  }

  /// Banks the practice and both rewards once, then freezes the before/after
  /// values the ending ritual will animate. The server still owns final truth;
  /// its absolute grant quietly reconciles the live stores behind this receipt.
  private func finishSession() {
    guard !didRecord else { return }
    didRecord = true

    let now = Date.now
    let gardenBefore = gardenStore.growth
    let heartBalanceBefore = heartLedger.balance
    let heartsEarnedTodayBefore = heartLedger.heartsEarnedToday
    let continuityBefore = practiceStore.currentStreakDays
    // Frozen before the ritual runs: whichever practice reaches the beat
    // first today is the one that shows it.
    let continuityWitnessedToday = continuityWitness.hasWitnessedToday

    practiceStore.recordCompletion(of: session)

    let completionsAfter = PracticeMath.completionsToday(
      in: practiceStore.completions,
      calendar: .current,
      now: now
    )
    let isRewardEligible = completionsAfter <= RewardRules.deepSessionDailyLimit
    let heartsAwarded = isRewardEligible ? heartLedger.earn() : 0
    // Deep Session rewards travel as one pair. If the heart ceiling withholds
    // this award, sunlight rests too, matching the server contract.
    let sunlightAwarded = heartsAwarded > 0 ? gardenStore.creditSunlight(1) : 0

    rewardReceipt = RewardReceipt(
      gardenBefore: gardenBefore,
      gardenAfter: gardenStore.growth,
      sunlightAwarded: sunlightAwarded,
      heartBalanceBefore: heartBalanceBefore,
      heartBalanceAfter: heartLedger.balance,
      heartsEarnedTodayBefore: heartsEarnedTodayBefore,
      heartsEarnedTodayAfter: heartLedger.heartsEarnedToday,
      heartsAwarded: heartsAwarded,
      continuityBefore: continuityBefore,
      continuityAfter: practiceStore.currentStreakDays,
      continuityWitnessedToday: continuityWitnessedToday
    )

    // Let the final exhale settle before the first reward blooms in.
    completionTask = Task {
      try? await Task.sleep(for: .seconds(1.0))
      guard !Task.isCancelled else { return }
      withAnimation(.hush) { stage = .completion }
    }
  }
}

#Preview("Deep session practice") {
  DeepSessionCoordinatorView(session: DeepSessionLibrary.balancingBreath)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
    .environment(\.practiceStore, MockPracticeStore())
    .environment(\.heartLedger, .sample)
    .environment(\.gardenStore, .sample)
    .environment(\.continuityWitness, .unwitnessed)
}
