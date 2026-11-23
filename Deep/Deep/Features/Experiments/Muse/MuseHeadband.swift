#if EXPERIMENTS && MUSE_SDK
import CoreBluetooth
import Foundation
@preconcurrency import Muse

// A real Muse 2, through Interaxon's LibMuse.
//
// Threading: LibMuse's manager (scanning, the list of headbands) runs its own
// CoreBluetooth central on the main queue and schedules timers on the current run
// loop, so `MuseHeadband` drives it on the main actor. Once a headband is chosen,
// `MuseLink` owns it on a serial queue and pumps it with `execute()` every 20 ms;
// packets arrive there synchronously and feed one `MuseFrameBuilder` with no locks.
// Ten times a second the link hands a `HeadbandTick` (a plain Sendable value) back to
// the main actor.

@MainActor
@Observable
final class MuseHeadband: MuseConnecting {
  let isSimulated = false
  private(set) var nearby: [HeadbandInfo] = []
  private(set) var link: HeadbandLink = .idle
  private(set) var fit: SensorFit = .unknown
  private(set) var battery: Double?
  private(set) var diagnostics = HeadbandDiagnostics()

  @ObservationIgnored private let fanout = TickFanout()
  @ObservationIgnored private lazy var museLink = MuseLink(owner: self)
  @ObservationIgnored private var manager: IXNMuseManagerIos?
  @ObservationIgnored private lazy var listListener = ListListener { [weak self] in self?.refreshList() }
  @ObservationIgnored private lazy var logListener = LogListener { [weak self] line in self?.libraryLogged(line) }
  @ObservationIgnored private var muses: [String: IXNMuse] = [:]
  /// The headband being connected or used, so its name survives a dropped link.
  @ObservationIgnored private var current: HeadbandInfo?
  @ObservationIgnored private var bluetooth: BluetoothWatch?
  @ObservationIgnored private var bluetoothState = CBManagerState.unknown
  @ObservationIgnored private var wantsScan = false
  @ObservationIgnored private var events: [String] = []
  @ObservationIgnored private var libraryLog: [String] = []
  @ObservationIgnored private var latest: MuseLink.Snapshot?

  func startScanning() {
    if link.headband != nil { return }
    wantsScan = true
    // Creating the watcher shows the Bluetooth permission prompt, after our own
    // explanation screen.
    if bluetooth == nil {
      bluetooth = BluetoothWatch { [weak self] state in self?.bluetoothChanged(state) }
    }
    switch CBManager.authorization {
    case .denied, .restricted:
      link = .failed(.bluetoothDenied)
      return
    default:
      break
    }
    if bluetoothState == .poweredOff {
      link = .failed(.bluetoothOff)
      return
    }
    let manager = self.manager ?? makeManager()
    nearby = []
    link = .scanning
    // A scan that died with the Bluetooth radio never restarts by itself, and
    // startListening does nothing while LibMuse thinks it is still listening.
    manager?.stopListening()
    manager?.startListening()
    note("scanning")
  }

  func stopScanning() {
    wantsScan = false
    manager?.stopListening()
    if link == .scanning { link = .idle }
  }

  func connect(_ headband: HeadbandInfo) {
    wantsScan = false
    // LibMuse: stop listening before connecting.
    manager?.stopListening()
    guard let muse = muses[headband.id] else {
      link = .failed(.connectionFailed)
      return
    }
    current = headband
    link = .connecting(headband)
    note("connecting to \(headband.name)")
    museLink.connect(muse)
  }

  func disconnect() {
    museLink.disconnect()
    current = nil
    link = .idle
    fit = .unknown
    battery = nil
    note("disconnected by user")
  }

  func ticks() -> AsyncStream<HeadbandTick> { fanout.stream() }

  private func makeManager() -> IXNMuseManagerIos? {
    guard let manager = IXNMuseManagerIos.sharedManager() else { return nil }
    manager.museListener = listListener
    // A headband that stops advertising drops off the list after ten seconds.
    manager.removeFromList(after: 10)
    if let log = IXNLogManager.instance() {
      log.setLogListener(logListener)
      log.setMinimumSeverity(.sevInfo)
    }
    self.manager = manager
    return manager
  }

  private func refreshList() {
    let found = manager?.getMuses() ?? []
    muses = Dictionary(found.map { ($0.getMacAddress(), $0) }, uniquingKeysWith: { first, _ in first })
    // The model isn't known until a headband connects (LibMuse reports 2016 before
    // then), so the list shows names only.
    nearby = found.map { HeadbandInfo(id: $0.getMacAddress(), name: $0.getName(), model: "Muse headband") }
  }

  // MARK: From the link (main actor)

  fileprivate func linkChanged(_ state: MuseLink.State) {
    let headband = current ?? HeadbandInfo(id: "?", name: "Muse", model: "Muse headband")
    switch state {
    case .connecting:
      if case .reconnecting = link { return }
      link = .connecting(headband)
    case .connected(let model):
      let named = HeadbandInfo(id: headband.id, name: headband.name, model: model)
      current = named
      link = .connected(named)
      note("connected (\(model))")
    case .reconnecting(let attempt):
      link = .reconnecting(headband, attempt: attempt)
      // The last reading is stale while the link is down.
      fit = .unknown
      note("link dropped, reconnect attempt \(attempt)")
    case .failed(let problem):
      current = nil
      link = .failed(problem)
      fit = .unknown
      note("failed: \(problem)")
    case .disconnected:
      fit = .unknown
      // Keep a failure on screen ("update your headband") rather than going idle.
      if case .failed = link { return }
      current = nil
      link = .idle
    }
  }

  fileprivate func received(_ tick: HeadbandTick) {
    if tick.fit != fit { fit = tick.fit }
    fanout.send(tick)
  }

  fileprivate func received(_ snapshot: MuseLink.Snapshot) {
    latest = snapshot
    if let level = snapshot.battery { battery = level }
    refreshDiagnostics()
  }

  private func libraryLogged(_ line: String) {
    libraryLog.append(line)
    if libraryLog.count > 100 { libraryLog.removeFirst(libraryLog.count - 100) }
  }

  private func bluetoothChanged(_ state: CBManagerState) {
    bluetoothState = state
    switch state {
    case .poweredOff:
      // A headband in use keeps its state: the link reports the drop and reconnects.
      if link.headband == nil { link = .failed(.bluetoothOff) }
      note("Bluetooth is off")
    case .unauthorized:
      link = .failed(.bluetoothDenied)
    case .poweredOn:
      guard case .failed(.bluetoothOff) = link else { return }
      link = .idle
      if wantsScan { startScanning() }
    default:
      break
    }
  }

  private func note(_ line: String) {
    events.append("\(Date().formatted(date: .omitted, time: .standard))  \(line)")
    if events.count > 60 { events.removeFirst() }
    refreshDiagnostics()
  }

  private func refreshDiagnostics() {
    var readings: [HeadbandDiagnostics.Reading] = [
      .init(label: "Link", value: "\(link)"),
      .init(label: "LibMuse", value: MuseSDK.version)
    ]
    if let snapshot = latest {
      readings += [
        .init(label: "Headband", value: "\(snapshot.name) · \(snapshot.model) · preset \(snapshot.preset)"),
        .init(label: "Battery", value: snapshot.battery.map { "\(Int($0 * 100))%" } ?? "—"),
        .init(label: "Packets/s", value: snapshot.rates),
        .init(label: "Ticks/s", value: String(format: "%.1f (%.0f%% with EEG)", snapshot.tickRate, snapshot.usableShare * 100)),
        .init(label: "Fit", value: snapshot.fit),
        .init(label: "α θ β γ δ", value: snapshot.bands),
        .init(label: "Calm", value: String(format: "%.2f", snapshot.calm)),
        .init(label: "Stillness", value: String(format: "%.2f (motion %.4f g)", snapshot.stillness, snapshot.motion)),
        .init(label: "Heart", value: snapshot.heart),
        .init(label: "Blinks · clenches", value: "\(snapshot.blinks) · \(snapshot.clenches)"),
        .init(label: "Reconnects", value: "\(snapshot.reconnects)")
      ]
    }
    diagnostics = HeadbandDiagnostics(readings: readings, log: events + libraryLog.suffix(40))
  }
}

// MARK: - The LibMuse side

/// Owns the chosen headband. Everything here runs on `queue`; only Sendable values
/// leave it.
private nonisolated final class MuseLink: NSObject, @unchecked Sendable {
  enum State: Sendable {
    case connecting, disconnected
    case connected(model: String)
    case reconnecting(attempt: Int)
    case failed(HeadbandProblem)
  }

  struct Snapshot: Sendable {
    var name = "", model = "", preset = ""
    var battery: Double?
    var rates = "", fit = "", bands = "", heart = ""
    var tickRate = 0.0, usableShare = 0.0
    var calm = 0.0, stillness = 0.0, motion = 0.0
    var blinks = 0, clenches = 0, reconnects = 0
  }

  /// Attempts before giving up on a headband that has never answered (the Muse app
  /// holds it, or it's off or out of range).
  static let firstConnectAttempts = 3

  private weak var owner: MuseHeadband?
  private let queue = DispatchQueue(label: "space.deeppeace.muse", qos: .userInitiated)
  private var muse: IXNMuse?
  private var timer: DispatchSourceTimer?
  private var builder = MuseFrameBuilder()
  private var wantsConnection = false
  private var everConnected = false
  private var attempts = 0
  private var pumpCount = 0
  private var battery: Double?
  private var snapshot = Snapshot()
  private var ticksSinceReport = 0
  private var usableSinceReport = 0
  private var countsAtReport: [String: Int] = [:]
  private var lastReportAt = Date()
  private let clockStart = Date()

  // Plain listener objects: LibMuse holds them weakly, so the link keeps them.
  private var connectionListener: ConnectionListener!
  private var dataListener: DataListener!

  private static let packetTypes: [IXNMuseDataPacketType] = [
    .alphaRelative, .betaRelative, .deltaRelative, .thetaRelative, .gammaRelative,
    .alphaAbsolute, .betaAbsolute, .deltaAbsolute, .thetaAbsolute, .gammaAbsolute,
    .hsiPrecision, .artifacts, .accelerometer, .ppg, .battery
  ]

  init(owner: MuseHeadband) {
    self.owner = owner
    super.init()
    connectionListener = ConnectionListener(link: self)
    dataListener = DataListener(link: self)
  }

  private var now: Double { Date().timeIntervalSince(clockStart) }

  private func toMain(_ work: @escaping @MainActor (MuseHeadband) -> Void) {
    DispatchQueue.main.async { [weak owner] in
      MainActor.assumeIsolated {
        if let owner { work(owner) }
      }
    }
  }

  // MARK: Connecting

  func connect(_ muse: IXNMuse) {
    queue.async { [self] in
      if let previous = self.muse, previous !== muse {
        previous.unregisterAllListeners()
        previous.disconnect()
      }
      self.muse = muse
      wantsConnection = true
      everConnected = false
      attempts = 0
      builder = MuseFrameBuilder()
      snapshot = Snapshot()
      snapshot.name = muse.getName()
      open(muse)
      startPump()
    }
  }

  /// Registers for everything the art needs and asks the headband to connect.
  private func open(_ muse: IXNMuse) {
    muse.unregisterAllListeners()
    muse.register(connectionListener)
    for type in Self.packetTypes {
      muse.register(dataListener, type: type)
    }
    // 4-channel EEG with PPG (heart rate). Set before connecting: the model isn't
    // known yet, and changing presets while connected forces a reconnect. Every Muse 2
    // supports it; LibMuse ignores a preset a headband can't use.
    muse.setPreset(.preset51)
    muse.connect()
  }

  func disconnect() {
    queue.async { [self] in
      wantsConnection = false
      guard let muse else { return }
      muse.disconnect()
      // LibMuse needs execute() until it reports DISCONNECTED (see `teardown`);
      // stop anyway if it never does.
      queue.asyncAfter(deadline: .now() + 5) { [self] in
        guard !wantsConnection, self.muse === muse else { return }
        teardown()
      }
    }
  }

  /// Stops pumping and lets the headband go.
  private func teardown() {
    stopPump()
    muse?.unregisterAllListeners()
    muse = nil
  }

  private func startPump() {
    timer?.cancel()
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now(), repeating: .milliseconds(20), leeway: .milliseconds(4))
    timer.setEventHandler { [weak self] in self?.pump() }
    timer.resume()
    self.timer = timer
  }

  private func stopPump() {
    timer?.cancel()
    timer = nil
  }

  /// Every 20 ms: let LibMuse work (packets arrive during `execute`). Every 100 ms:
  /// one tick to the main actor.
  private func pump() {
    muse?.execute()
    pumpCount += 1
    guard pumpCount % 5 == 0, muse?.getConnectionState() == .connected else { return }
    let tick = builder.makeTick(at: now)
    ticksSinceReport += 1
    if tick.frame != nil { usableSinceReport += 1 }
    toMain { $0.received(tick) }
    if pumpCount % 50 == 0 { report(tick) }
  }

  /// Called by LibMuse during `execute()`. Never connect, disconnect or unregister from
  /// in here: schedule it on the queue instead.
  fileprivate func connectionChanged(_ state: IXNConnectionState) {
    switch state {
    case .connecting:
      if attempts == 0 { toMain { $0.linkChanged(.connecting) } }
    case .connected:
      attempts = 0
      everConnected = true
      let model = muse.map { Self.modelName($0.getModel()) } ?? "Muse"
      snapshot.model = model
      snapshot.preset = muse?.getConfiguration().map { Self.presetName($0.getPreset()) } ?? "?"
      toMain { $0.linkChanged(.connected(model: model)) }
    case .disconnected:
      guard wantsConnection, let muse else {
        queue.async { [self] in teardown() }
        toMain { $0.linkChanged(.disconnected) }
        return
      }
      attempts += 1
      // A headband that never answered: stop trying and say so.
      if !everConnected, attempts >= Self.firstConnectAttempts {
        wantsConnection = false
        queue.async { [self] in teardown() }
        toMain { $0.linkChanged(.failed(.connectionFailed)) }
        return
      }
      snapshot.reconnects += 1
      let attempt = attempts
      toMain { $0.linkChanged(.reconnecting(attempt: attempt)) }
      let delay = min(pow(2, Double(attempt - 1)), 5)
      queue.asyncAfter(deadline: .now() + delay) { [self] in
        guard wantsConnection, self.muse === muse, muse.getConnectionState() != .connected else { return }
        open(muse)
      }
    case .needsUpdate:
      wantsConnection = false
      toMain { $0.linkChanged(.failed(.needsFirmwareUpdate)) }
      queue.async { [self] in muse?.disconnect() }
    case .needsLicense:
      wantsConnection = false
      toMain { $0.linkChanged(.failed(.needsLicense)) }
      queue.async { [self] in muse?.disconnect() }
    default:
      break
    }
  }

  // MARK: Packets (on `queue`, during `execute`)

  fileprivate func received(_ packet: IXNMuseDataPacket) {
    let time = now
    func channels() -> [Double] {
      [IXNEeg.EEG1, .EEG2, .EEG3, .EEG4].map { packet.getEegChannelValue($0) }
    }
    switch packet.packetType() {
    case .alphaRelative: builder.ingestBand(.alpha, isRelative: true, channels: channels(), at: time)
    case .betaRelative: builder.ingestBand(.beta, isRelative: true, channels: channels(), at: time)
    case .deltaRelative: builder.ingestBand(.delta, isRelative: true, channels: channels(), at: time)
    case .thetaRelative: builder.ingestBand(.theta, isRelative: true, channels: channels(), at: time)
    case .gammaRelative: builder.ingestBand(.gamma, isRelative: true, channels: channels(), at: time)
    case .alphaAbsolute: builder.ingestBand(.alpha, isRelative: false, channels: channels(), at: time)
    case .betaAbsolute: builder.ingestBand(.beta, isRelative: false, channels: channels(), at: time)
    case .deltaAbsolute: builder.ingestBand(.delta, isRelative: false, channels: channels(), at: time)
    case .thetaAbsolute: builder.ingestBand(.theta, isRelative: false, channels: channels(), at: time)
    case .gammaAbsolute: builder.ingestBand(.gamma, isRelative: false, channels: channels(), at: time)
    case .hsiPrecision: builder.ingestFit(channels(), at: time)
    case .accelerometer:
      builder.ingestAccelerometer(
        x: packet.getAccelerometerValue(.X),
        y: packet.getAccelerometerValue(.Y),
        z: packet.getAccelerometerValue(.Z),
        at: time
      )
    case .ppg: builder.ingestPPG(packet.getPpgChannelValue(.IR), at: time)
    case .battery:
      let percent = packet.getBatteryValue(.chargePercentageRemaining)
      if percent.isFinite { battery = min(max(percent / 100, 0), 1) }
    default: break
    }
  }

  fileprivate func received(_ packet: IXNMuseArtifactPacket) {
    builder.ingestArtifact(headbandOn: packet.headbandOn, blink: packet.blink, jawClench: packet.jawClench, at: now)
    if packet.blink { snapshot.blinks += 1 }
    if packet.jawClench { snapshot.clenches += 1 }
  }

  /// Once a second: what the diagnostics panel shows.
  private func report(_ tick: HeadbandTick) {
    let elapsed = max(Date().timeIntervalSince(lastReportAt), 0.001)
    lastReportAt = Date()
    let counts = builder.counts
    snapshot.rates = counts.keys.sorted().map { key in
      let rate = Double(counts[key, default: 0] - countsAtReport[key, default: 0]) / elapsed
      return "\(key) \(Int(rate.rounded()))"
    }.joined(separator: " · ")
    countsAtReport = counts
    snapshot.tickRate = Double(ticksSinceReport) / elapsed
    snapshot.usableShare = ticksSinceReport > 0 ? Double(usableSinceReport) / Double(ticksSinceReport) : 0
    ticksSinceReport = 0
    usableSinceReport = 0
    snapshot.battery = battery
    snapshot.fit = (tick.fit.headbandOn ? "on" : "OFF") + " · " + tick.fit.channels.map(\.label).joined(separator: " ")
    snapshot.motion = builder.motion.motion
    snapshot.stillness = builder.motion.stillness
    snapshot.heart = builder.heart.bpm.map { String(format: "%.0f bpm (locked)", $0) } ?? "no lock"
    if let frame = tick.frame {
      let r = frame.relative
      snapshot.bands = String(format: "%.2f %.2f %.2f %.2f %.2f", r.alpha, r.theta, r.beta, r.gamma, r.delta)
      snapshot.calm = frame.calm
    } else {
      snapshot.bands = "no usable EEG"
    }
    let snapshot = snapshot
    toMain { $0.received(snapshot) }
  }

  private static func modelName(_ model: IXNMuseModel) -> String {
    switch model {
    case .mu01: "Muse (2014)"
    case .mu02: "Muse (2016)"
    case .mu03, .mu04, .mu05: "Muse 2"
    case .mu06: "Muse 2 (2024)"
    case .ms03: "Muse S Athena"
    default: "Muse"
    }
  }

  private static func presetName(_ preset: IXNMusePreset) -> String {
    switch preset {
    case .preset51: "51 (EEG + PPG)"
    case .preset21: "21 (EEG)"
    default: "\(preset.rawValue)"
    }
  }
}

// MARK: - Listeners

// LibMuse's manager and log manager are process-wide singletons: their listeners hold
// weak references back, so a callback after we're gone does nothing.

private nonisolated final class ListListener: NSObject, IXNMuseListener, @unchecked Sendable {
  private let changed: @MainActor () -> Void
  init(changed: @escaping @MainActor () -> Void) { self.changed = changed }
  func museListChanged() {
    DispatchQueue.main.async { [changed] in MainActor.assumeIsolated { changed() } }
  }
}

private nonisolated final class LogListener: NSObject, IXNLogListener, @unchecked Sendable {
  private let logged: @MainActor (String) -> Void
  init(logged: @escaping @MainActor (String) -> Void) { self.logged = logged }
  func receiveLog(_ log: IXNLogPacket) {
    let line = "\(log.tag): \(log.message)"
    DispatchQueue.main.async { [logged] in MainActor.assumeIsolated { logged(line) } }
  }
}

private nonisolated final class ConnectionListener: NSObject, IXNMuseConnectionListener, @unchecked Sendable {
  private weak var link: MuseLink?
  init(link: MuseLink) { self.link = link }
  func receive(_ packet: IXNMuseConnectionPacket, muse: IXNMuse?) {
    link?.connectionChanged(packet.currentConnectionState)
  }
}

private nonisolated final class DataListener: NSObject, IXNMuseDataListener, @unchecked Sendable {
  private weak var link: MuseLink?
  init(link: MuseLink) { self.link = link }
  func receive(_ packet: IXNMuseDataPacket?, muse: IXNMuse?) {
    if let packet { link?.received(packet) }
  }
  func receive(_ packet: IXNMuseArtifactPacket, muse: IXNMuse?) {
    link?.received(packet)
  }
}

/// Watches the Bluetooth radio so the connect screen can say "turn Bluetooth on".
private final class BluetoothWatch: NSObject, CBCentralManagerDelegate {
  private var central: CBCentralManager?
  private let changed: (CBManagerState) -> Void

  init(changed: @escaping (CBManagerState) -> Void) {
    self.changed = changed
    super.init()
    central = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
  }

  nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
    let state = central.state
    MainActor.assumeIsolated { changed(state) }
  }
}
#endif
