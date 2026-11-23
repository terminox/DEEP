#if EXPERIMENTS
import SwiftUI

/// A live demo: the art playing a simulated 10-minute sit at 4× speed, looping until
/// the person closes it. No headband needed.
struct LiveDemoView: View {
  let art: EEGArt
  @Environment(\.dismiss) private var dismiss
  @State private var conductor = SitConductor(
    headband: SimulatedHeadband(speed: Self.speed, connected: true),
    length: EEGSessionRecording.duration,
    loops: true
  )

  /// Session seconds per wall second. 4, so a 10-minute sit plays in two and a half;
  /// `-experimentSpeed 20` in debug builds, to reach the end quickly.
  private static var speed: Double {
    #if DEBUG
    let override = UserDefaults.standard.double(forKey: "experimentSpeed")
    if override > 0 { return override }
    #endif
    return 4
  }

  var body: some View {
    ExperimentStage(art: art, conductor: conductor, isDemo: true) { dismiss() }
  }
}

#Preview("Lantern demo") {
  LiveDemoView(art: .lantern)
}

#Preview("Aurora demo") {
  LiveDemoView(art: .aurora)
}
#endif
