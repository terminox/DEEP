#if EXPERIMENTS
import SwiftUI

/// The full-screen frame around an artwork while it plays: one quiet button that
/// fades away (tap to bring it back), the pause veil, and the screen rules (may turn
/// sideways, never sleeps, no status bar). Long-press anywhere for the diagnostics.
struct ExperimentStage: View {
  let art: EEGArt
  let conductor: SitConductor
  /// A real sit ends with "End" (asks first) and closes with "Done"; a demo just closes.
  let isDemo: Bool
  let onClose: () -> Void

  @State private var showsControls = true
  @State private var hideControls: Task<Void, Never>?
  @State private var confirmsEnd = false
  @State private var showsDiagnostics = false

  private var sit: LiveSit { conductor.sit }

  var body: some View {
    art.artwork(for: sit)
      .id(ObjectIdentifier(sit))
      .ignoresSafeArea()
      .contentShape(Rectangle())
      .onTapGesture(perform: revealControls)
      .onLongPressGesture(minimumDuration: 1.2) {
        withAnimation(.settle) { showsDiagnostics.toggle() }
      }
      .overlay {
        if let pause = sit.pause, !isDemo {
          PauseVeil(pause: pause)
            .transition(.opacity)
        }
      }
      .overlay(alignment: .topLeading) {
        if showsControls || (sit.isFinished && !isDemo) {
          stageButton
            .padding(.leading, .edge)
            .padding(.top, 8)
            .transition(.opacity)
        }
      }
      .overlay(alignment: .bottom) {
        if sit.isFinished, !isDemo {
          finishedCaption
            .transition(.opacity)
        }
      }
      .overlay(alignment: .topTrailing) {
        if showsDiagnostics {
          HeadbandDiagnosticsView(headband: conductor.headband, sit: sit) {
            withAnimation(.settle) { showsDiagnostics = false }
          }
          .padding(.top, 8)
          .padding(.trailing, .edge)
          .transition(.opacity)
        }
      }
      .animation(.exhale, value: sit.pause)
      .animation(.hush, value: sit.isFinished)
      .confirmationDialog("End this sit?", isPresented: $confirmsEnd, titleVisibility: .visible) {
        Button("End sit", role: .destructive) { conductor.finish() }
        Button("Keep sitting", role: .cancel) {}
      } message: {
        Text("The art keeps what you've painted so far.")
      }
      .statusBarHidden()
      .persistentSystemOverlays(.hidden)
      .preferredColorScheme(.dark)
      .onAppear {
        OrientationLock.allow(art.orientations)
        UIApplication.shared.isIdleTimerDisabled = true
        conductor.start()
        revealControls()
      }
      .onDisappear {
        conductor.stop()
        hideControls?.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        OrientationLock.allow(.portrait)
      }
  }

  @ViewBuilder
  private var stageButton: some View {
    if isDemo || sit.isFinished {
      StageButton(title: sit.isFinished && !isDemo ? "Done" : "Close", systemImage: "xmark", action: onClose)
        .accessibilityIdentifier("experiment.close")
    } else {
      StageButton(title: "End", systemImage: "stop.fill") { confirmsEnd = true }
        .accessibilityIdentifier("experiment.end")
    }
  }

  private var finishedCaption: some View {
    Text(sit.elapsed >= sit.length ? "Your sit is complete" : "Sit ended")
      .font(DeepType.caption)
      .foregroundStyle(.moonCream.opacity(0.8))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(.ultraThinMaterial, in: Capsule())
      .padding(.bottom, 24)
  }

  /// Shows the button, then lets it fade after three seconds.
  private func revealControls() {
    withAnimation(.settle) { showsControls = true }
    hideControls?.cancel()
    hideControls = Task {
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      withAnimation(.hush) { showsControls = false }
    }
  }
}

/// The one control on a playing artwork: a frosted circle with an icon.
private struct StageButton: View {
  let title: LocalizedStringKey
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button(title, systemImage: systemImage, action: action)
      .labelStyle(.iconOnly)
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(.moonCream)
      .frame(width: 44, height: 44)
      .background(.ultraThinMaterial, in: Circle())
  }
}

/// Dims the art while the sit waits for the signal to come back.
private struct PauseVeil: View {
  let pause: SitPause

  var body: some View {
    ZStack {
      Color.black.opacity(0.45)
      VStack(spacing: 10) {
        if pause == .reconnecting {
          ProgressView()
            .tint(.moonCream)
        } else {
          Image(systemName: "brain.head.profile")
            .font(.system(size: 26, weight: .light))
            .foregroundStyle(.moonCream)
        }
        Text(pause == .reconnecting ? "Reconnecting…" : "Can't feel the headband")
          .font(DeepType.sectionTitle)
          .foregroundStyle(.moonCream)
        Text(pause == .reconnecting
          ? "Your sit will carry on when it's back."
          : "Settle it on your forehead and behind your ears to carry on.")
          .font(DeepType.caption)
          .foregroundStyle(.moonCream.opacity(0.75))
          .multilineTextAlignment(.center)
      }
      .padding(28)
      .frame(maxWidth: 320)
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }
}

#Preview("Stage · Aurora demo") {
  ExperimentStage(
    art: .aurora,
    conductor: SitConductor(headband: SimulatedHeadband(speed: 4, connected: true), length: 600, loops: true),
    isDemo: true,
    onClose: {}
  )
}

#Preview("Stage · Lantern sit") {
  ExperimentStage(
    art: .lantern,
    conductor: SitConductor(headband: SimulatedHeadband(speed: 4, connected: true), length: 180),
    isDemo: false,
    onClose: {}
  )
}
#endif
