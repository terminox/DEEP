import SwiftUI

/// The guided breathing screen — a full-bleed atmosphere with the orb at
/// centre, the phase cue beneath it, and one soft control. A projection of
/// `BreathEngine` state: the engine keeps time, this view breathes.
///
/// Leaf screen, so it owns all screen-level styling (per the coordinator
/// rules); `DeepSessionCoordinatorView` only composes and wires dismissal.
struct DeepSessionView: View {
  var engine: BreathEngine
  /// The finished checkmark — carries the flow into its completion beat.
  var onFinish: () -> Void = {}
  var onClose: () -> Void = {}

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The orb's presented fullness. Driven by phase changes so the very first
  /// inhale animates from rest instead of rendering already-swollen.
  @State private var swell: CGFloat = 0
  /// The orb's presence under Reduce Motion — the breath rendered as light
  /// instead of size, while `swell` stays pinned.
  @State private var glow: Double = 1

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
          .opacity(glow)
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
        .accessibilityElement(children: .combine)
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
    // A soft tap at each turn of the breath, so the practice works with eyes
    // closed. The system's haptics setting is honoured automatically; inhale
    // lands slightly firmer than exhale so the pair reads as rise / release.
    .sensoryFeedback(trigger: engine.phase) { _, phase in
      switch phase {
      case .inhale: .impact(weight: .light, intensity: 0.8)
      case .exhale: .impact(weight: .light, intensity: 0.5)
      case .finished: .impact(weight: .medium, intensity: 0.6)
      }
    }
    .onAppear { breathe(into: engine.phase) }
    .onChange(of: engine.phase) { _, phase in
      breathe(into: phase)
      announceCue()
    }
    .onChange(of: engine.isPaused) { _, isPaused in
      isPaused ? freezeBreath() : resumeBreath()
      announceCue()
    }
  }

  // MARK: - Breath motion

  /// Carries the orb towards the target of the new phase, at that phase's own
  /// tempo and on the design system's breath curve — the one motion in the app
  /// allowed to take whole seconds. Under Reduce Motion the orb holds still
  /// and breathes as light instead.
  private func breathe(into phase: BreathEngine.Phase) {
    if reduceMotion {
      swell = 0.6
      switch phase {
      case .inhale:
        withAnimation(.breath(over: engine.session.inhale)) { glow = 1 }
      case .exhale:
        withAnimation(.breath(over: engine.session.exhale)) { glow = 0.7 }
      case .finished:
        withAnimation(.bloom) { glow = 1 }
      }
      return
    }

    switch phase {
    case .inhale:
      withAnimation(.breath(over: engine.session.inhale)) { swell = 1 }
    case .exhale:
      withAnimation(.breath(over: engine.session.exhale)) { swell = 0 }
    case .finished:
      withAnimation(.bloom) { swell = 0.6 }
    }
  }

  /// Pins the orb at its true mid-flight position: each phase animates the
  /// full 0…1 travel on the breath curve, so sampling that curve at the
  /// phase's elapsed fraction reproduces the presented value, and setting it
  /// without animation replaces the in-flight animation with stillness.
  private func freezeBreath() {
    guard !reduceMotion, engine.phase != .finished,
          let remaining = engine.remainingInPhase,
          engine.currentPhaseDuration > 0
    else { return }

    let progress = min(1, max(0, 1 - remaining / engine.currentPhaseDuration))
    let eased = UnitCurve.breath.value(at: progress)
    var stillness = Transaction()
    stillness.disablesAnimations = true
    withTransaction(stillness) {
      swell = engine.phase == .inhale ? eased : 1 - eased
    }
  }

  /// Carries the orb the rest of the way, over the time the phase has left.
  /// (The curve restarts across the remaining travel — imperceptible at
  /// breath-length durations.)
  private func resumeBreath() {
    guard !reduceMotion, engine.phase != .finished,
          let remaining = engine.remainingInPhase
    else { return }

    withAnimation(.breath(over: remaining)) {
      swell = engine.phase == .inhale ? 1 : 0
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

  /// Speaks the visual cue, so VoiceOver users breathe with the session too.
  private func announceCue() {
    AccessibilityNotification.Announcement(cue).post()
  }

  // MARK: - Control

  private var controlButton: some View {
    Button {
      if engine.phase == .finished {
        onFinish()
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
