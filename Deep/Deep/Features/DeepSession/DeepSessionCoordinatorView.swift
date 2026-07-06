import SwiftUI

/// Composition root for one guided Deep Session, presented full-screen by
/// `MainTabController` over whichever tab launched it. Owns the session's
/// engine and the dismissal handshake; all styling lives in the leaf
/// `DeepSessionView` (per the coordinator rules).
struct DeepSessionCoordinatorView: View {
  @State private var engine: BreathEngine
  private let onDismiss: () -> Void

  init(session: DeepSession, onDismiss: @escaping () -> Void) {
    _engine = State(initialValue: BreathEngine(session: session))
    self.onDismiss = onDismiss
  }

  var body: some View {
    DeepSessionView(engine: engine, onClose: onDismiss)
      .onAppear { engine.begin() }
      .onDisappear { engine.cancel() }
  }
}

#Preview("Deep session coordinator") {
  DeepSessionCoordinatorView(session: DeepSessionLibrary.balancingBreath) {}
}
