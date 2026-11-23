#if EXPERIMENTS
import SwiftUI

/// The EEG artworks in Settings → Experiments. Each plays a `LiveSit`, so the same art
/// serves a live demo (simulated headband, looping) and a real sit on a Muse 2.
enum EEGArt: String, CaseIterable, Identifiable {
  case lantern
  case aurora

  var id: String { rawValue }

  var title: String {
    switch self {
    case .lantern: "Lantern Exhibition"
    case .aurora: "Aurora"
    }
  }

  var icon: String {
    switch self {
    case .lantern: "flame"
    case .aurora: "sparkles"
    }
  }

  /// One line for the length picker.
  var promise: String {
    switch self {
    case .lantern: "A lantern rises every few seconds. Calm moments glow brighter."
    case .aurora: "The northern lights move with your brainwaves."
    }
  }

  /// Both sky scenes may turn sideways; everything else stays upright.
  var orientations: UIInterfaceOrientationMask {
    switch self {
    case .lantern, .aurora: .allButUpsideDown
    }
  }

  @ViewBuilder
  func artwork(for sit: LiveSit) -> some View {
    switch self {
    case .lantern: LanternArtView(sit: sit)
    case .aurora: AuroraArtView(sit: sit)
    }
  }
}

/// What Settings opens full screen.
enum ExperimentLaunch: Identifiable {
  case demo(EEGArt)
  case sit(EEGArt)

  var id: String {
    switch self {
    case .demo(let art): "demo.\(art.rawValue)"
    case .sit(let art): "sit.\(art.rawValue)"
    }
  }
}
#endif
