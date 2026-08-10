#if DEBUG
import SwiftUI

/// Dedicated experimental screen for tuning the Earth orb — the app root
/// boots straight into it when `DeepApp.bootIntoEarthTuningLab` is on.
///
/// Deliberately standalone: it owns its own seeded `GlobalPauseEarthScene`
/// and touches no production screen (lobby, meditation, feed). The globe
/// fills the top of the screen and stays fully interactive (drag, flick,
/// tap-a-country); the tuning panel scrolls beneath it. Both drive the same
/// live objects — `EarthTuning.shared` plus this scene's stores — so every
/// slider lands on the next rendered frame.
struct EarthTuningLabView: View {
  @State private var scene: GlobalPauseEarthScene = {
    // A seeded world so glow/spark knobs have something to act on:
    // city points plus a "you are here" breathing home glow (Bangkok).
    let scene = GlobalPauseEarthScene()
    scene.glow.homeLocation = PauseJoinPoint(lat: 13.8, lon: 100.5)
    scene.glow.locations = EarthGlowStore.sampleCities
    return scene
  }()

  var body: some View {
    VStack(spacing: 0) {
      LabEarthSceneView(scene: scene)
        .frame(maxWidth: .infinity)
        .frame(height: 340)
        .padding(.top, 8)

      EarthTuningPanel(scene: scene, tuning: .shared)
    }
    .background(
      LinearGradient(
        colors: [.moonCream, Color.softLilac.opacity(0.35)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
    )
  }
}

/// Debug-only bridge for the shipping UIKit globe, mirroring the one in
/// `Earth3DDebugHarness` (which is private to that file).
private struct LabEarthSceneView: UIViewRepresentable {
  let scene: GlobalPauseEarthScene

  func makeUIView(context: Context) -> EarthSceneView {
    let view = EarthSceneView(
      glow: scene.glow,
      interaction: scene.interaction,
      ripples: scene.ripples
    )
    view.isInteractive = true
    return view
  }

  func updateUIView(_ uiView: EarthSceneView, context: Context) {}
}

#Preview {
  // Hermetic: the lab seeds its own scene; a fresh EarthTuning would detach
  // the sliders from the preview's renderer (which reads .shared), so the
  // preview accepts the shared instance — still no networking, no players.
  EarthTuningLabView()
}
#endif
