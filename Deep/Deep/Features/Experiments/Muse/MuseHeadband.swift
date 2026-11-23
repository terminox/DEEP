#if EXPERIMENTS && MUSE_SDK
import CoreBluetooth
import Foundation
@preconcurrency import Muse

// A real Muse 2, through Interaxon's LibMuse.
//
// Threading: every LibMuse call happens on `MuseLink`'s serial queue, which pumps the
// headband with `execute()` every 20 ms, so packets arrive there synchronously and
// feed one `MuseFrameBuilder` with no locks. Ten times a second the link hands a
// `HeadbandTick` (a plain Sendable value) to the main actor. `MuseHeadband` is what
// the UI observes.

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
  @ObservationIgnored private var bluetooth: BluetoothWatch?
  @ObservationIgnored private var events: [String] = []
  @ObservationIgnored private var libraryLog: [String] = []
  @ObservationIgnored private var latest: MuseLink.Snapshot?

  func startScanning() {
    if link.headband != nil { return }
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
    nearby = []
    link = .scanning
    museLink.startScanning()
    note("scanning")
  }

  func stopScanning() {
    museLink.stopScanning()
    if link == .scanning { link = .idle }
  }

  func connect(_ headband: HeadbandInfo) {
    link = .connecting(headband)
    note("connecting to \(headband.name)")
    museLink.connect(id: headband.id)
  }

  func disconnect() {
    museLink.disconnect()
    link = .idle
    fit = .unknown
    battery = nil
    note("disconnected by user")
  }

  func ticks() -> AsyncStream<HeadbandTick> { fanout.stream() }

  // MARK: From the link (main actor)

  fileprivate func found(_ headbands: [HeadbandInfo]) {
    nearby = headbands
  }

  fileprivate func linkChanged(_ state: MuseLink.State) {
    let headband = link.headband ?? nearby.first ?? HeadbandInfo(id: "?", name: "Muse", model: "Muse 2")
    switch state {
    case .connecting:
      if case .reconnecting = link { return }
      link = .connecting(headband)
    case .connected:
      link = .connected(headband)
      note("connected")
    case .reconnecting(let attempt):
      link = .reconnecting(headband, attempt: attempt)
      note("link dropped, reconnect attempt \(attempt)")
    case .failed(let problem):
      link = .failed(problem)
      note("failed: \(problem)")
    case .disconnected:
      link = .idle
      fit = .unknown
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

  fileprivate func libraryLogged(_ line: String) {
    libraryLog.append(line)
    if libraryLog.count > 100 { libraryLog.removeFirst(libraryLog.count - 100) }
  }

  private func bluetoothChanged(_ state: CBManagerState) {
    switch state {
    case .poweredOff:
      link = .failed(.bluetoothOff)
      note("Bluetooth is off")
    case .unauthorized:
      link = .failed(.bluetoothDenied)
    case .poweredOn:
      if case .failed(.bluetoothOff) = link { link = .idle }
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

/// Owns LibMuse. Everything here runs on `queue`; only Sendable values leave it.
private nonisolated final class MuseLink: NSObject, @unchecked Sendable {
  enum State: Sendable {
    case connecting, connected, disconnected
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

  private weak var owner: MuseHeadband?
  private let queue = DispatchQueue(label: "space.deeppeace.muse", qos: .userInitiated)
  private var manager: IXNMuseManagerIos?
  private var muse: IXNMuse?
  private var timer: DispatchSourceTimer?
  private var builder = MuseFrameBuilder()
  private var wantsConnection = false
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
  private var listListener: ListListener!
  private var connectionListener: ConnectionListener!
  private var dataListener: DataListener!
  private var logListener: LogListener!

  private static let packetTypes: [IXNMuseDataPacketType] = [
    .alphaRelative, .betaRelative, .deltaRelative, .thetaRelative, .gammaRelative,
    .alphaAbsolute, .betaAbsolute, .deltaAbsolute, .thetaAbsolute, .gammaAbsolute,
    .hsiPrecision, .artifacts, .accelerometer, .ppg, .battery
  ]

  init(owner: MuseHeadband) {
    self.owner = owner
    super.init()
    listListener = ListListener(link: self)
    connectionListener = ConnectionListener(link: self)
    dataListener = DataListener(link: self)
    logListener = LogListener(link: self)
  }

  private var now: Double { Date().timeIntervalSince(clockStart) }

  private func toMain(_ work: @escaping @MainActor (MuseHeadband) -> Void) {
    DispatchQueue.main.async { [weak owner] in
      MainActor.assumeIsolated {
        if let owner { work(owner) }
      }
    }
  }

  // MARK: Scanning

  func startScanning() {
    queue.async { [self] in
      if manager == nil, let manager = IXNMuseManagerIos.sharedManager() {
        manager.museListener = listListener
        manager.removeFromList(after: 10)
        self.manager = manager
        if let log = IXNLogManager.instance() {
          log.setLogListener(logListener)
          log.setMinimumSeverity(.sevInfo)
        }
      }
      manager?.startListening()
    }
  }

  func stopScanning() {
    queue.async { [self] in manager?.stopListening() }
  }

  fileprivate func listChanged() {
    queue.async { [self] in
      let headbands = (manager?.getMuses() ?? []).map { muse in
        HeadbandInfo(id: muse.getMacAddress(), name: muse.getName(), model: Self.modelName(muse.getModel()))
      }
      toMain { $0.found(headbands) }
    }
  }

  // MARK: Connecting

  func connect(id: String) {
    queue.async { [self] in
      guard let manager, let muse = manager.getMuses().first(where: { $0.getMacAddress() == id }) else {
        toMain { $0.linkChanged(.failed(.connectionFailed)) }
        return
      }
      // LibMuse: stop listening before connecting.
      manager.stopListening()
      self.muse = muse
      wantsConnection = true
      attempts = 0
      builder = MuseFrameBuilder()
      snapshot = Snapshot()
      snapshot.name = muse.getName()
      snapshot.model = Self.modelName(muse.getModel())
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
    // 4-channel EEG with PPG (heart rate), for every Muse 2 from 2018 to the 2024 USB-C.
    let preset: IXNMusePreset = [.mu03, .mu04, .mu05, .mu06].contains(muse.getModel()) ? .preset51 : .preset21
    muse.setPreset(preset)
    snapshot.preset = preset == .preset51 ? "51 (EEG + PPG)" : "21 (EEG)"
    muse.connect()
  }

  func disconnect() {
    queue.async { [self] in
      wantsConnection = false
      muse?.disconnect()
      // Keep pumping briefly so LibMuse can finish disconnecting, then stop.
      queue.asyncAfter(deadline: .now() + 1) { [self] in
        guard !wantsConnection else { return }
        stopPump()
        muse?.unregisterAllListeners()
        muse = nil
      }
    }
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

  fileprivate func connectionChanged(_ state: IXNConnectionState) {
    switch state {
    case .connecting:
      if attempts == 0 { toMain { $0.linkChanged(.connecting) } }
    case .connected:
      attempts = 0
      toMain { $0.linkChanged(.connected) }
    case .disconnected:
      guard wantsConnection, let muse else {
        toMain { $0.linkChanged(.disconnected) }
        return
      }
      // Never reconnect from inside LibMuse's callback: schedule it.
      attempts += 1
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
    case .needsLicense:
      wantsConnection = false
      toMain { $0.linkChanged(.failed(.needsLicense)) }
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

  fileprivate func logged(_ log: IXNLogPacket) {
    let line = "\(log.tag): \(log.message)"
    toMain { $0.libraryLogged(line) }
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
}

// MARK: - Listeners

private nonisolated final class ListListener: NSObject, IXNMuseListener, @unchecked Sendable {
  private unowned let link: MuseLink
  init(link: MuseLink) { self.link = link }
  func museListChanged() { link.listChanged() }
}

private nonisolated final class ConnectionListener: NSObject, IXNMuseConnectionListener, @unchecked Sendable {
  private unowned let link: MuseLink
  init(link: MuseLink) { self.link = link }
  func receive(_ packet: IXNMuseConnectionPacket, muse: IXNMuse?) {
    link.connectionChanged(packet.currentConnectionState)
  }
}

private nonisolated final class DataListener: NSObject, IXNMuseDataListener, @unchecked Sendable {
  private unowned let link: MuseLink
  init(link: MuseLink) { self.link = link }
  func receive(_ packet: IXNMuseDataPacket?, muse: IXNMuse?) {
    if let packet { link.received(packet) }
  }
  func receive(_ packet: IXNMuseArtifactPacket, muse: IXNMuse?) {
    link.received(packet)
  }
}

private nonisolated final class LogListener: NSObject, IXNLogListener, @unchecked Sendable {
  private unowned let link: MuseLink
  init(link: MuseLink) { self.link = link }
  func receiveLog(_ log: IXNLogPacket) { link.logged(log) }
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
