import Observation

/// The one Earth behind the Global Pause tab. The single shared
/// `GlobalPauseCardView` renders it through one `EarthSceneView`; glow and
/// orientation live here so previews and any future surfaces can share the
/// same planet.
@MainActor
@Observable
final class GlobalPauseEarthScene {
  let glow = EarthGlowStore()
  let interaction = EarthInteraction()
}

#if DEBUG
extension GlobalPauseEarthScene {
  /// A seeded world for previews — the same live counts as
  /// `EarthGlowStore.previewActive`.
  static var preview: GlobalPauseEarthScene {
    let scene = GlobalPauseEarthScene()
    scene.glow.participantsByCountry = EarthGlowStore.previewActive.participantsByCountry
    return scene
  }
}
#endif
