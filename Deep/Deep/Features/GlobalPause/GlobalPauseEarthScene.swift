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

  /// A 5s poll delivers joins in a batch; draining them apart makes each
  /// spark + ripple read as an individual person arriving. Capped so a flood
  /// never keeps sparking long after the moment has passed.
  @ObservationIgnored private var joinQueue: [PauseJoinPoint] = []
  @ObservationIgnored private var drainTask: Task<Void, Never>?
  private let joinQueueCap = 10
  /// The beat between two arrivals — slow enough that each reads as its own
  /// person rather than a flicker.
  private let joinBeat = Duration.milliseconds(150)
  /// …but a batch has to finish inside the glow's rise (one `lerpTau`), or its
  /// tail flares onto light that already finished coming up. Big batches
  /// tighten their beat to fit; the one- or two-join batches a live poll
  /// delivers keep the full 150ms.
  private let joinBurstWindow = Duration.milliseconds(900)

  /// The one entry point for "someone joined": fires the glow spark and the
  /// halo ring together at the same coordinates.
  func enqueueJoins(_ joins: [PauseJoinPoint]) {
    guard !joins.isEmpty else { return }
    joinQueue.append(contentsOf: joins)
    if joinQueue.count > joinQueueCap {
      joinQueue.removeFirst(joinQueue.count - joinQueueCap)
    }
    startDraining()
  }

  /// *Your* arrival, and only yours: it jumps the queue and skips the cap,
  /// because it is the one join the session's gate was built for — a flood of
  /// strangers must never trim it away or bury it a second deep.
  func enqueueOwnJoin(_ join: PauseJoinPoint) {
    joinQueue.insert(join, at: 0)
    startDraining()
  }

  private func startDraining() {
    guard drainTask == nil else { return }
    drainTask = Task { [weak self] in
      while let self, !Task.isCancelled, !self.joinQueue.isEmpty {
        let beat = min(self.joinBeat, self.joinBurstWindow / self.joinQueue.count)
        let join = self.joinQueue.removeFirst()
        self.glow.spark(lat: join.lat, lon: join.lon)
        // The flat 2D canvas ring belongs to the classic spark style; the
        // flash + shell style carries its own 3D wave in the shader.
        if self.glow.tuning.sparkStyle == .classic {
          self.ripples.emit(lat: join.lat, lon: join.lon)
        }
        try? await Task.sleep(for: beat)
      }
      self?.drainTask = nil
    }
  }

  /// Session teardown: neither a queued join nor one already in flight may
  /// land on the resting card as it flies home — a spark lives 2s and a ring
  /// 1.2s, both longer than the 0.45s reverse flight. The world's lights
  /// belong to the session alone.
  func clearJoins() {
    drainTask?.cancel()
    drainTask = nil
    joinQueue.removeAll()
    glow.clearSparks()
    ripples.clear()
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
