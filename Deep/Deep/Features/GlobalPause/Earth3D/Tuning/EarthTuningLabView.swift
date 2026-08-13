#if DEBUG
import SwiftUI

/// Dedicated experimental screen for tuning the Earth orb — the app root
/// boots straight into it when `DeepApp.bootIntoEarthTuningLab` is on.
///
/// Deliberately standalone: it owns its own seeded `GlobalPauseEarthScene`
/// and touches no production screen (lobby, meditation, feed). The globe
/// fills the top of the screen and stays fully interactive (drag, flick,
/// tap-a-country); the DialKit drawer (see `EarthDials`) floats over it and
/// mirrors every dial into the live objects — `EarthTuning.shared` plus this
/// scene's stores — so each change lands on the next rendered frame.
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
    ZStack {
      VStack(spacing: 0) {
        LabEarthSceneView(scene: scene)
          .frame(maxWidth: .infinity)
          .frame(height: 420)
          .padding(.top, 8)

        Spacer(minLength: 0)
      }

      EarthDialsOverlay(scene: scene)
    }
    .background {
      // Panel toggle flips between the night sky under tuning and the
      // original cream gradient, for A/B comparison.
      if NightSkyTuning.shared.enabled {
        NightSkyBackground(tuning: .shared)
          .ignoresSafeArea()
      } else {
        LinearGradient(
          colors: [.moonCream, Color.softLilac.opacity(0.35)],
          startPoint: .top,
          endPoint: .bottom
        )
        .ignoresSafeArea()
      }
    }
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

  func updateUIView(_ uiView: EarthSceneView, context: Context) {
    // updateUIView tracks these @Observable reads, so both the dim slider and
    // the night-sky toggle re-invoke it.
    let sky = NightSkyTuning.shared
    uiView.backdropAlpha = sky.enabled ? CGFloat(sky.values.earthBackdropDim) : 1
  }
}

#Preview {
  // Hermetic: the lab seeds its own scene; a fresh EarthTuning would detach
  // the sliders from the preview's renderer (which reads .shared), so the
  // preview accepts the shared instance — still no networking, no players.
  EarthTuningLabView()
}
#endif
