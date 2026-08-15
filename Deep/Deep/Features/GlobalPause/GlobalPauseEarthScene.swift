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
  /// each ripple read as an individual person arriving. Capped so a flood
  /// never keeps ringing long after the moment has passed.
  @ObservationIgnored private var joinQueue: [PauseJoinPoint] = []
  @ObservationIgnored private var drainTask: Task<Void, Never>?
  private let joinQueueCap = 10

  /// The one entry point for "someone joined": each join lands as a halo
  /// ring at its coordinates — the ring alone is the arrival; the steady
  /// glow the poll seeds is the person staying.
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
        self.ripples.emit(lat: join.lat, lon: join.lon)
        try? await Task.sleep(for: .milliseconds(150))
      }
      self?.drainTask = nil
    }
  }

  /// Session teardown: joins still waiting in the queue must not ring onto
  /// the resting card as it flies home — the world's lights belong to the
  /// session alone.
  func cancelPendingJoins() {
    drainTask?.cancel()
    drainTask = nil
    joinQueue.removeAll()
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
