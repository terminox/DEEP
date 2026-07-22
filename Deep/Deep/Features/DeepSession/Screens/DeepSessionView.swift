import SwiftUI

/// The guided breathing screen — a full-bleed atmosphere with the orb at
/// centre, the phase cue beneath it, and one soft control. A projection of
/// `BreathEngine` state: the engine keeps time, this view breathes.
///
/// Leaf screen, so it owns all screen-level styling (per the coordinator
/// rules); `DeepSessionCoordinatorView` only composes and wires dismissal.
struct DeepSessionView: View {
  var engine: BreathEngine
  var onClose: () -> Void = {}

  /// The orb's presented fullness. Driven by phase changes so the very first
  /// inhale animates from rest instead of rendering already-swollen.
  @State private var swell: CGFloat = 0

  var body: some View {
    ZStack {
      // Opaque base under the atmosphere's translucent stops: the session is
      // presented over the shell, and the launching screen must never show
      // through — including mid-zoom.
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()

      VStack(spacing: 0) {
        Spacer()

        BreathingOrb(swell: swell)
          .frame(width: 280)

        VStack(spacing: 8) {
          Text(cue)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
            .contentTransition(.opacity)
            .animation(.bloom, value: cue)
          Text(caption)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .contentTransition(.opacity)
            .animation(.bloom, value: caption)
        }
        .padding(.top, .rhythm * 1.5)

        Spacer()

        controlButton
          .padding(.bottom, .rhythm)
      }
      .padding(.horizontal, .edge)
    }
    .overlay(alignment: .topLeading) {
      GlassCloseButton(action: onClose)
        .padding(.edge)
    }
    .onAppear { breathe(into: engine.phase) }
    .onChange(of: engine.phase) { _, phase in breathe(into: phase) }
  }

  // MARK: - Breath motion

  /// Carries the orb towards the target of the new phase, at that phase's own
  /// tempo and on the design system's exhale curve — the one motion in the app
  /// allowed to take whole seconds.
  private func breathe(into phase: BreathEngine.Phase) {
    switch phase {
    case .inhale:
      withAnimation(.timingCurve(0.32, 0.0, 0.36, 1.0, duration: engine.session.inhale)) {
        swell = 1
      }
    case .exhale:
      withAnimation(.timingCurve(0.32, 0.0, 0.36, 1.0, duration: engine.session.exhale)) {
        swell = 0
      }
    case .finished:
      withAnimation(.bloom) { swell = 0.6 }
    }
  }

  // MARK: - Copy

  private var cue: String {
    switch engine.phase {
    case .finished: "You’re here now"
    case _ where engine.isPaused: "Paused"
    case .inhale: "Breathe in"
    case .exhale: "Breathe out"
    }
  }

  private var caption: String {
    switch engine.phase {
    case .finished: "Session complete"
    case _ where engine.isPaused: "Take your time"
    default: "Round \(engine.cycle) of \(engine.session.cycles)"
    }
  }

  // MARK: - Control

  private var controlButton: some View {
    Button {
      if engine.phase == .finished {
        onClose()
      } else {
        engine.togglePaused()
      }
    } label: {
      Image(systemName: controlSymbol)
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 64, height: 64)
        .background(
          Circle().fill(LinearGradient(
            colors: [.lavenderMist, .softLilac],
            startPoint: .topLeading, endPoint: .bottomTrailing
          ))
        )
        .shadow(color: .lavenderMist.opacity(0.4), radius: 12, x: 0, y: 6)
    }
    .buttonStyle(.softPress)
    .accessibilityLabel(controlLabel)
  }

  private var controlSymbol: String {
    switch engine.phase {
    case .finished: "checkmark"
    case _ where engine.isPaused: "play.fill"
    default: "pause.fill"
    }
  }

  private var controlLabel: String {
    switch engine.phase {
    case .finished: "Finish session"
    case _ where engine.isPaused: "Resume"
    default: "Pause"
    }
  }
}

#Preview("Deep session — inhale") {
  DeepSessionView(engine: .still(phase: .inhale, cycle: 2))
}

#Preview("Deep session — paused") {
  DeepSessionView(engine: .still(phase: .exhale, cycle: 4, isPaused: true))
}

#Preview("Deep session — complete") {
  DeepSessionView(engine: .still(phase: .finished, cycle: 6))
}
