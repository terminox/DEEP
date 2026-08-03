import SwiftUI

/// The lobby's SwiftUI layer, floated over the UIKit shell (globe card below,
/// glass close button above). One view per phase, crossfaded; the globe
/// choreography and audio react to the same `session.phase` from the lobby
/// controller, so this layer is purely presentational.
///
/// Non-scrolling phases keep their empty space hit-transparent (the hosting
/// container lets those touches fall through to the globe); the feedback
/// phase owns its touches — its scroll view runs under the shrunken globe.
struct GlobalPauseLobbyOverlayView: View {
  @Environment(\.globalPauseSession) private var session

  var body: some View {
    ZStack {
      switch session.phase {
      case .loading:
        Color.clear
      case .offHours:
        GlobalPauseOffHoursView()
          .transition(.softDrift)
      case .lobby:
        GlobalPauseLiveLobbyView()
          .transition(.softDrift)
      case .welcome:
        GlobalPauseWelcomeView()
          .transition(.softDrift)
      case .meditation:
        GlobalPauseMeditationView()
          .transition(.softDrift)
      case .feedback:
        GlobalPauseFeedbackView()
          .transition(.softDrift)
      }
    }
    .animation(.hush, value: phaseKind)
    .safeAreaInset(edge: .bottom) {
      #if DEBUG
      if AppConfig.current.isDev {
        devPhaseStrip
      }
      #endif
    }
  }

  /// Phase identity without associated values, so the crossfade doesn't
  /// re-fire on every off-hours countdown target refresh.
  private var phaseKind: String {
    switch session.phase {
    case .loading: "loading"
    case .offHours: "offHours"
    case .lobby: "lobby"
    case .welcome: "welcome"
    case .meditation: "meditation"
    case .feedback: "feedback"
    }
  }

  #if DEBUG
  /// Dev-only phase jumps: pins the synced clock inside a phase window (and
  /// forwards the pin to the backend via X-Debug-Now). "Real" unpins.
  private var devPhaseStrip: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        devChip("Off") { session.debugJump(to: nil) }
        devChip("Lobby") { session.debugJump(to: .lobby) }
        devChip("Welcome") { session.debugJump(to: .welcome) }
        devChip("Med") { session.debugJump(to: .meditation) }
        devChip("Fdbk") { session.debugJump(to: .feedback) }
        devChip("Real") { session.debugJump(to: nil) }
      }
      .padding(.horizontal, .edge)
    }
    .padding(.vertical, 6)
  }

  private func devChip(_ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(DeepType.micro)
        .foregroundStyle(.deepPlum)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.6)))
    }
    .buttonStyle(.softPress)
  }
  #endif
}

#Preview("Overlay — lobby") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    GlobalPauseLobbyOverlayView()
      .environment(\.globalPauseSession, .preview(phase: .lobby))
      .environment(\.pauseReminder, MockPauseReminder())
  }
}

#Preview("Overlay — feedback") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    GlobalPauseLobbyOverlayView()
      .environment(\.globalPauseSession, .preview(phase: .feedback))
      .environment(\.pauseReminder, MockPauseReminder())
  }
}
