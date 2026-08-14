import Observation

/// The one Earth behind the Global Pause tab. The single shared
/// `GlobalPauseCardView` renders it through one `EarthSceneView`; glow,
/// orientation, and join ripples live here so previews and any future
/// surfaces can share the same planet — a join seen in the lobby is the same
/// ring the feed card would show.
@MainActor
@Observable
final class GlobalPauseEarthScene {
  let glow = EarthGlowStore()
  let interaction = EarthInteraction()
  let ripples = EarthHaloRipples()

  /// A 5s poll delivers joins in a batch; draining them 150ms apart makes
  /// each spark + ripple read as an individual person arriving. Capped so a
  /// flood never keeps sparking long after the moment has passed.
  @ObservationIgnored private var joinQueue: [PauseJoinPoint] = []
  @ObservationIgnored private var drainTask: Task<Void, Never>?
  private let joinQueueCap = 10

  /// The one entry point for "someone joined": fires the glow spark and the
  /// halo ring together at the same coordinates.
  func enqueueJoins(_ joins: [PauseJoinPoint]) {
    guard !joins.isEmpty else { return }
    joinQueue.append(contentsOf: joins)
    if joinQueue.count > joinQueueCap {
      joinQueue.removeFirst(joinQueue.count - joinQueueCap)
    }
    guard drainTask == nil else { return }
    drainTask = Task { [weak self] in
      while let self, !Task.isCancelled, !self.joinQueue.isEmpty {
        let join = self.joinQueue.removeFirst()
        self.glow.spark(lat: join.lat, lon: join.lon)
        // The flat 2D canvas ring belongs to the classic spark style; the
        // flash + shell style carries its own 3D wave in the shader.
        if self.glow.tuning.sparkStyle == .classic {
          self.ripples.emit(lat: join.lat, lon: join.lon)
        }
        try? await Task.sleep(for: .milliseconds(150))
      }
      self?.drainTask = nil
    }
  }
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

  /// A point-glow world — city clusters, the shape live IP-located data takes.
  static var previewCities: GlobalPauseEarthScene {
    let scene = GlobalPauseEarthScene()
    scene.glow.locations = EarthGlowStore.sampleCities
    return scene
  }
}
#endif
