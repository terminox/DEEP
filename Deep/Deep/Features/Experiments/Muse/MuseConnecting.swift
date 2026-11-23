#if EXPERIMENTS
import Foundation

// The headband, as the experiments see it. Two implementations:
// - `MuseHeadband`: a real Muse 2 over LibMuse (device builds with the SDK, see
//   Deep/Config/Muse.xcconfig).
// - `SimulatedHeadband`: plays a generated sit. The simulator, builds without the SDK,
//   every live demo and every preview use it.
// One shared instance (`Headbands.shared`) owns the connection, so the headband stays
// connected while the person moves from one art to the next.

/// A headband seen while scanning.
nonisolated struct HeadbandInfo: Identifiable, Hashable, Sendable {
  /// LibMuse's MAC address string (a stable per-device identifier on iOS).
  let id: String
  let name: String
  let model: String
}

/// Why a headband can't be used right now.
enum HeadbandProblem: Equatable {
  case bluetoothOff
  case bluetoothDenied
  /// The headband's firmware is too old for LibMuse: update it in the Muse app.
  case needsFirmwareUpdate
  case needsLicense
  case connectionFailed
}

/// Where the connection is.
enum HeadbandLink: Equatable {
  case idle
  case scanning
  case connecting(HeadbandInfo)
  case connected(HeadbandInfo)
  /// The link dropped mid-use; trying again.
  case reconnecting(HeadbandInfo, attempt: Int)
  case failed(HeadbandProblem)

  var headband: HeadbandInfo? {
    switch self {
    case .connecting(let headband), .connected(let headband), .reconnecting(let headband, _): headband
    case .idle, .scanning, .failed: nil
    }
  }

  var isConnected: Bool {
    if case .connected = self { return true }
    return false
  }
}

/// How well the four sensors touch the skin, TP9 · AF7 · AF8 · TP10.
nonisolated struct SensorFit: Equatable, Sendable {
  var channels: [HorseshoeFit]
  var headbandOn: Bool

  static let unknown = SensorFit(channels: Array(repeating: .bad, count: 4), headbandOn: false)

  var isGood: Bool { headbandOn && channels.allSatisfy { $0 == .good } }
  var goodCount: Int { channels.count { $0 == .good } }
}

/// One tenth of a second from the headband.
nonisolated struct HeadbandTick: Sendable {
  /// Nil while there is no usable EEG: the headband is off, every sensor is lifted,
  /// or the data went stale.
  var frame: EEGFrame?
  /// Artifacts that began in this tick.
  var artifacts: [EEGArtifactKind]
  var fit: SensorFit
}

/// What a tester can read off the hidden diagnostics panel and paste back to us.
struct HeadbandDiagnostics: Equatable {
  /// Labelled readings, in display order.
  var readings: [Reading] = []
  /// Recent link events and LibMuse log lines, oldest first.
  var log: [String] = []

  struct Reading: Equatable, Identifiable {
    let label: String
    let value: String
    var id: String { label }
  }
}

@MainActor
protocol MuseConnecting: AnyObject, Observable {
  /// True for the simulated headband (simulator, demos, builds without LibMuse).
  var isSimulated: Bool { get }
  /// Headbands found by the current scan.
  var nearby: [HeadbandInfo] { get }
  var link: HeadbandLink { get }
  var fit: SensorFit { get }
  /// 0…1, once the headband has reported it.
  var battery: Double? { get }
  var diagnostics: HeadbandDiagnostics { get }

  func startScanning()
  func stopScanning()
  func connect(_ headband: HeadbandInfo)
  func disconnect()
  /// A fresh stream of ticks for each caller, while connected. Ends when the caller
  /// stops iterating.
  func ticks() -> AsyncStream<HeadbandTick>
}

/// The one headband the app talks to.
enum Headbands {
  static let shared: any MuseConnecting = {
    #if MUSE_SDK
    MuseHeadband()
    #elseif DEBUG
    // `-experimentSpeed 10` plays the simulated sit faster, for QA.
    SimulatedHeadband(speed: max(UserDefaults.standard.double(forKey: "experimentSpeed"), 1))
    #else
    SimulatedHeadband()
    #endif
  }()
}

/// Hands every tick to each open `ticks()` stream.
@MainActor
final class TickFanout {
  private var continuations: [UUID: AsyncStream<HeadbandTick>.Continuation] = [:]

  func stream() -> AsyncStream<HeadbandTick> {
    let (stream, continuation) = AsyncStream.makeStream(of: HeadbandTick.self, bufferingPolicy: .bufferingNewest(64))
    continuations[UUID()] = continuation
    return stream
  }

  /// Streams whose reader has gone are dropped on the next send.
  func send(_ tick: HeadbandTick) {
    for (id, continuation) in continuations {
      if case .terminated = continuation.yield(tick) { continuations[id] = nil }
    }
  }
}
#endif
