import SwiftUI

/// Composition root for the full Deep Session flow — intro threshold, guided
/// session, then the completion beat — presented full-screen (via
/// `deepSessionLaunch`) over whichever tab launched it. Owns the stage switch,
/// the engine, the dismissal handshake, recording the finished practice, and
/// silencing the ambient player; all styling lives in the leaf screens (per
/// the coordinator rules).
struct DeepSessionCoordinatorView: View {
  private enum Stage {
    case intro
    case session
    case completion
  }

  private let session: DeepSession
  @State private var stage: Stage = .intro
  @State private var engine: BreathEngine
  /// The completion is credited exactly once, the moment the engine finishes —
  /// so closing from the finished screen still counts.
  @State private var didRecord = false

  @Environment(\.dismiss) private var dismiss
  @Environment(\.soundPlayer) private var soundPlayer
  @Environment(\.practiceStore) private var practiceStore
  @Environment(\.heartLedger) private var heartLedger
  @Environment(\.scenePhase) private var scenePhase

  init(session: DeepSession) {
    self.session = session
    _engine = State(initialValue: BreathEngine(session: session))
  }

  var body: some View {
    ZStack {
      // A plain crossfade, not a navigation container: the stages only ever
      // move forward (the only way back out is dismissing the flow), and every
      // screen sits on an opaque base, so the fade can't reveal the tab
      // beneath.
      switch stage {
      case .intro:
        DeepSessionIntroView(
          session: session,
          onBegin: { withAnimation(.bloom) { stage = .session } },
          onClose: { dismiss() }
        )
        .transition(.opacity)
      case .session:
        DeepSessionView(
          engine: engine,
          onFinish: { withAnimation(.bloom) { stage = .completion } },
          onClose: { dismiss() }
        )
        .transition(.opacity)
        // The first inhale starts under the crossfade from the intro.
        .onAppear { engine.begin() }
      case .completion:
        DeepSessionCompletionView(onReturn: { dismiss() })
          .transition(.opacity)
      }
    }
    .onAppear {
      // A guided breath and ambient audio don't mix — the flow begins in
      // silence. The track stays loaded, so the mini player is waiting on
      // return.
      soundPlayer.pause()
      // A breath practice is hands-off; don't let the screen sleep mid-round.
      UIApplication.shared.isIdleTimerDisabled = true
    }
    .onDisappear {
      engine.cancel()
      UIApplication.shared.isIdleTimerDisabled = false
    }
    .onChange(of: engine.phase) { _, phase in
      guard phase == .finished, !didRecord else { return }
      didRecord = true
      practiceStore.recordCompletion(of: session)
      heartLedger.earn()
    }
    // Leaving the app settles the practice into a pause; resuming stays the
    // user's own gesture. `.inactive` is deliberately ignored — banners and
    // Control Center shouldn't interrupt a breath.
    .onChange(of: scenePhase) { _, phase in
      guard phase == .background else { return }
      engine.pause()
    }
  }
}

#Preview("Deep session flow") {
  DeepSessionCoordinatorView(session: DeepSessionLibrary.balancingBreath)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
    .environment(\.practiceStore, MockPracticeStore())
    .environment(\.heartLedger, .sample)
}
