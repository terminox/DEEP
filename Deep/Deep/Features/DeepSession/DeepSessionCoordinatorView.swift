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
  /// Whether this session actually earned a heart. A day hands over at most
  /// `HeartLedger.dailyEarnCeiling` of them, so the completion beat has to know
  /// before it promises one.
  @State private var heartEarned = true

  @Environment(\.soundPlayer) private var soundPlayer
  @Environment(\.practiceStore) private var practiceStore
  @Environment(\.heartLedger) private var heartLedger
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
        DeepSessionCompletionView(
          session: session,
          heartEarned: heartEarned,
          onReturn: onFinish
        )
          .transition(.softDrift)
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
      engine.cancel()
      UIApplication.shared.isIdleTimerDisabled = false
    }
    .onChange(of: engine.phase) { _, phase in
      guard phase == .finished, !didRecord else { return }
      didRecord = true
      practiceStore.recordCompletion(of: session)
      heartEarned = heartLedger.earn() > 0
      // Let the final exhale settle (the orb blooms to its rest) before the
      // hush into the completion beat — no tap required to move on. The
      // longer crossfade absorbs part of what used to be dead time, so the
      // finish beat stays ~2s in total.
      Task {
        try? await Task.sleep(for: .seconds(1.0))
        withAnimation(.hush) { stage = .completion }
      }
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

#Preview("Deep session practice") {
  DeepSessionCoordinatorView(session: DeepSessionLibrary.balancingBreath)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
    .environment(\.practiceStore, MockPracticeStore())
    .environment(\.heartLedger, .sample)
}
