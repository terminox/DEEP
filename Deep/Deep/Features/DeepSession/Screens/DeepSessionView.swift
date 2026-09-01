import SwiftUI

/// The guided breathing screen — a full-bleed atmosphere with the orb at
/// centre, the phase cue beneath it, and one soft control. A projection of
/// `BreathEngine` state: the engine keeps time, this view breathes.
///
/// The first inhale never lands unannounced: the view runs a short settling
/// countdown before starting the engine. And once the last exhale settles the
/// control fades away — the coordinator carries the flow into its completion
/// beat on its own, so this screen holds no finished-state interaction.
///
/// Leaf screen, so it owns all screen-level styling (per the coordinator
/// rules); `DeepSessionCoordinatorView` only composes and wires dismissal.
struct DeepSessionView: View {
  var engine: BreathEngine
  var onClose: () -> Void = {}
  /// Seconds of settling before the first inhale. Previews pass 0 to pin
  /// mid-session states without the pre-roll.
  var countdownSeconds: Int = 3

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  /// The orb's presented fullness. Driven by phase changes so the very first
  /// inhale animates from rest instead of rendering already-swollen.
  @State private var swell: CGFloat = 0
  /// The orb's presence under Reduce Motion — the breath rendered as light
  /// instead of size, while `swell` stays pinned.
  @State private var glow: Double = 1
  /// The settling count still to show; `nil` once breathing has begun.
  @State private var countdown: Int?
  @State private var countdownTask: Task<Void, Never>?
  /// Leaving mid-practice asks first; the flag alongside remembers a manual
  /// pause so "Keep breathing" doesn't overrule it.
  @State private var showLeaveConfirm = false
  @State private var wasPausedBeforeConfirm = false

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

        cueBlock
          .padding(.top, .rhythm * 1.5)

        Spacer()

        controlButton
          .opacity(controlHidden ? 0 : 1)
          .disabled(controlHidden)
          .accessibilityHidden(controlHidden)
          .animation(.bloom, value: controlHidden)
          .padding(.bottom, .rhythm)
      }
      .padding(.horizontal, .edge)
    }
    .overlay(alignment: .topLeading) {
      GlassCloseButton(action: requestClose)
        .padding(.edge)
    }
    .alert("Leave your session?", isPresented: $showLeaveConfirm) {
      Button("Leave", role: .destructive) { onClose() }
      Button("Keep breathing", role: .cancel) {
        if !wasPausedBeforeConfirm { engine.togglePaused() }
      }
    } message: {
      Text("Your breath will be here whenever you’re ready to return.")
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
    // A lighter tick for each settling count; the hand-off into the first
    // inhale stays silent so the breath itself makes the first real mark.
    .sensoryFeedback(trigger: countdown) { _, count in
      count == nil ? nil : .impact(weight: .light, intensity: 0.4)
    }
    .onAppear { startCountdown() }
    .onDisappear { countdownTask?.cancel() }
    .onChange(of: engine.phase) { _, phase in
      breathe(into: phase)
      announceCue()
    }
    .onChange(of: engine.isPaused) { _, isPaused in
      isPaused ? freezeBreath() : resumeBreath()
      announceCue()
    }
    // A suspended sleep fires the instant the app returns, which would slam
    // straight into the first inhale — restart the settling count instead.
    .onChange(of: scenePhase) { _, phase in
      guard countdown != nil else { return }
      if phase == .background {
        countdownTask?.cancel()
        countdownTask = nil
      } else if phase == .active, countdownTask == nil {
        startCountdown()
      }
    }
  }

  // MARK: - Settling in

  /// Begins the practice — after the settling count when one is configured,
  /// immediately otherwise. Also the re-entry point when the app comes back
  /// mid-countdown.
  private func startCountdown() {
    guard countdownSeconds > 0, engine.phase != .finished else {
      breathe(into: engine.phase)
      engine.begin()
      return
    }

    countdown = countdownSeconds
    AccessibilityNotification.Announcement("Settling in. \(countdownSeconds)").post()
    if reduceMotion {
      swell = 0.6
      glow = 0.7
      withAnimation(.breath(over: Double(countdownSeconds))) { glow = 0.85 }
    } else {
      // The orb gathers slightly, so the first inhale can fill from it.
      withAnimation(.breath(over: Double(countdownSeconds))) { swell = 0.25 }
    }
    countdownTask = Task {
      for count in stride(from: countdownSeconds - 1, through: 1, by: -1) {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        countdown = count
        AccessibilityNotification.Announcement("\(count)").post()
      }
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      countdown = nil
      countdownTask = nil
      breathe(into: .inhale)
      engine.begin()
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

  // MARK: - Leaving early

  /// Mid-practice, leaving asks first — the breath freezes under the alert so
  /// nothing moves while the user decides. The countdown and the finished
  /// settle hold nothing to lose, so they dismiss directly.
  private func requestClose() {
    guard countdown == nil, engine.phase != .finished else {
      onClose()
      return
    }
    wasPausedBeforeConfirm = engine.isPaused
    engine.pause()
    showLeaveConfirm = true
  }

  // MARK: - Cue

  private var cueBlock: some View {
    Group {
      if let count = countdown {
        VStack(spacing: 8) {
          Text(verbatim: "\(count)")
            .font(DeepType.bigNumber)
            .monospacedDigit()
            .foregroundStyle(.deepPlum)
            .contentTransition(.numericText(countsDown: true))
            .animation(.exhale, value: countdown)
          Text("Settling in")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        }
      } else {
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
      }
    }
    .animation(.bloom, value: countdown == nil)
    .accessibilityElement(children: .combine)
  }

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
    default: remainingLine
    }
  }

  /// How much practice is still ahead, coarse on purpose — a ten-minute session
  /// counted in rounds reads as a tally to get through. Recomputed at each turn
  /// of the breath (the engine's phase is observed) rather than on a clock, so
  /// nothing new ticks on a screen meant to be watched with the eyes half shut.
  private var remainingLine: String {
    let left = engine.remainingInSession
    if left < 30 { return "Almost there" }
    if left < 90 { return "About a minute left" }
    return "About \(Int((left / 60).rounded())) min left"
  }

  /// Speaks the visual cue, so VoiceOver users breathe with the session too.
  private func announceCue() {
    AccessibilityNotification.Announcement(cue).post()
  }

  // MARK: - Control

  /// The control fades away while the settling count runs and once the
  /// session has finished — from there the flow moves on by itself.
  private var controlHidden: Bool {
    countdown != nil || engine.phase == .finished
  }

  private var controlButton: some View {
    Button {
      engine.togglePaused()
    } label: {
      Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
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
    .accessibilityLabel(engine.isPaused ? "Resume" : "Pause")
  }
}

#Preview("Deep session — countdown") {
  DeepSessionView(engine: .still(phase: .inhale))
}

#Preview("Deep session — inhale") {
  DeepSessionView(engine: .still(phase: .inhale, cycle: 2), countdownSeconds: 0)
}

#Preview("Deep session — paused") {
  DeepSessionView(engine: .still(phase: .exhale, cycle: 4, isPaused: true), countdownSeconds: 0)
}

#Preview("Deep session — complete") {
  DeepSessionView(engine: .still(phase: .finished, cycle: 6), countdownSeconds: 0)
}
