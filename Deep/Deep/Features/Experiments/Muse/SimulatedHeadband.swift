#if EXPERIMENTS
import Foundation

/// A pretend Muse 2 that plays a generated sit (`EEGSessionRecording`). It behaves like
/// the real one where the UI can tell (a scan that finds it, a connection that takes a
/// moment, sensors that settle) so the whole sit flow runs on the simulator.
@MainActor
@Observable
final class SimulatedHeadband: MuseConnecting {
  static let name = "Muse-SIM"

  let isSimulated = true
  private(set) var nearby: [HeadbandInfo] = []
  private(set) var link: HeadbandLink = .idle
  private(set) var fit: SensorFit = .unknown
  private(set) var battery: Double?
  private(set) var diagnostics = HeadbandDiagnostics()

  /// Session seconds of the recording per wall second: 1 for a sit, 4 for a demo.
  var speed: Double

  @ObservationIgnored private let recording: EEGSessionRecording
  @ObservationIgnored private let fanout = TickFanout()
  @ObservationIgnored private var cursor = 0
  @ObservationIgnored private var pump: Task<Void, Never>?
  @ObservationIgnored private var pending: Task<Void, Never>?
  @ObservationIgnored private var dropUntil: Date?
  @ObservationIgnored private var ticksSent = 0

  private static let headband = HeadbandInfo(id: "00:55:DA:00:00:00", name: name, model: "Muse 2 (simulated)")

  /// - Parameter connected: start connected (live demos, previews) instead of idle.
  init(recording: EEGSessionRecording = .regular, speed: Double = 1, connected: Bool = false) {
    self.recording = recording
    self.speed = speed
    if connected {
      link = .connected(Self.headband)
      battery = 0.82
      startPump()
    }
  }

  func startScanning() {
    guard !link.isConnected else { return }
    link = .scanning
    nearby = []
    pending?.cancel()
    pending = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1.5))
      guard !Task.isCancelled, let self, self.link == .scanning else { return }
      self.nearby = [Self.headband]
    }
  }

  func stopScanning() {
    pending?.cancel()
    if link == .scanning { link = .idle }
  }

  func connect(_ headband: HeadbandInfo) {
    pending?.cancel()
    link = .connecting(headband)
    note("connecting to \(headband.name)")
    pending = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled, let self else { return }
      self.link = .connected(headband)
      self.battery = 0.82
      self.cursor = 0
      self.note("connected")
      self.startPump()
    }
  }

  func disconnect() {
    pending?.cancel()
    pump?.cancel()
    pump = nil
    link = .idle
    fit = .unknown
    battery = nil
    note("disconnected")
  }

  func ticks() -> AsyncStream<HeadbandTick> { fanout.stream() }

  /// Pretends the Bluetooth link dropped, to exercise "Reconnecting…".
  func simulateDrop(for seconds: Double) {
    guard let headband = link.headband else { return }
    dropUntil = Date().addingTimeInterval(seconds)
    link = .reconnecting(headband, attempt: 1)
    note("link dropped (simulated)")
  }

  // MARK: Playback

  private func startPump() {
    pump?.cancel()
    pump = Task { [weak self] in
      while !Task.isCancelled {
        self?.tick()
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  /// Ten times a second, hands out `speed` frames' worth of the recording.
  private func tick() {
    if let dropUntil {
      guard Date() >= dropUntil, let headband = link.headband else { return }
      self.dropUntil = nil
      link = .connected(headband)
      note("reconnected")
    }
    guard link.isConnected else { return }
    let frames = recording.frames
    let count = max(Int(speed.rounded()), 1)
    for _ in 0..<count {
      let frame = frames[cursor]
      cursor = (cursor + 1) % frames.count
      var artifacts: [EEGArtifactKind] = []
      if frame.blink { artifacts.append(.blink) }
      if frame.jawClench { artifacts.append(.jawClench) }
      let fit = SensorFit(channels: frame.fit, headbandOn: true)
      if fit != self.fit { self.fit = fit }
      fanout.send(HeadbandTick(frame: frame, artifacts: artifacts, fit: fit))
      ticksSent += 1
    }
    if ticksSent % 10 == 0 { refreshDiagnostics() }
  }

  private func refreshDiagnostics() {
    let frame = recording.frames[cursor]
    diagnostics.readings = [
      .init(label: "Headband", value: "Simulated (\(EEGPerson.regular.label))"),
      .init(label: "Speed", value: "\(Int(speed))×"),
      .init(label: "Calm", value: String(format: "%.2f", frame.calm)),
      .init(label: "α θ β", value: String(format: "%.2f %.2f %.2f", frame.relative.alpha, frame.relative.theta, frame.relative.beta)),
      .init(label: "Stillness", value: String(format: "%.2f", frame.stillness)),
      .init(label: "Heart rate", value: String(format: "%.0f bpm", frame.heartRate))
    ]
  }

  private func note(_ line: String) {
    diagnostics.log.append("\(Date().formatted(date: .omitted, time: .standard))  \(line)")
    if diagnostics.log.count > 100 { diagnostics.log.removeFirst() }
  }
}
#endif
