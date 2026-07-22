import SwiftUI

/// Composition root for the full Deep Session flow — intro threshold, then the
/// guided session — presented full-screen (via `deepSessionLaunch`) over
/// whichever tab launched it. Owns the stage switch, the engine, the dismissal
/// handshake, and silencing the ambient player; all styling lives in the leaf
/// screens (per the coordinator rules).
struct DeepSessionCoordinatorView: View {
  private enum Stage {
    case intro
    case session
  }

  private let session: DeepSession
  @State private var stage: Stage = .intro
  @State private var engine: BreathEngine

  @Environment(\.dismiss) private var dismiss
  @Environment(\.soundPlayer) private var soundPlayer

  init(session: DeepSession) {
    self.session = session
    _engine = State(initialValue: BreathEngine(session: session))
  }

  var body: some View {
    ZStack {
      // A plain crossfade, not a navigation container: Begin is one-way (the
      // only way back out is dismissing the flow), and both screens sit on an
      // opaque base, so the fade can't reveal the tab beneath.
      switch stage {
      case .intro:
        DeepSessionIntroView(
          session: session,
          onBegin: { withAnimation(.bloom) { stage = .session } },
          onClose: { dismiss() }
        )
        .transition(.opacity)
      case .session:
        DeepSessionView(engine: engine) { dismiss() }
          .transition(.opacity)
          // The first inhale starts under the crossfade from the intro.
          .onAppear { engine.begin() }
      }
    }
    // A guided breath and ambient audio don't mix — the flow begins in
    // silence. The track stays loaded, so the mini player is waiting on return.
    .onAppear { soundPlayer.pause() }
    .onDisappear { engine.cancel() }
  }
}

#Preview("Deep session flow") {
  DeepSessionCoordinatorView(session: DeepSessionLibrary.balancingBreath)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}
