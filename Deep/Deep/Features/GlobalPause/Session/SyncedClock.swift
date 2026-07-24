import Foundation
import Observation

/// The Global Pause clock: device time corrected toward the server's.
///
/// Phase boundaries are shared instants — a device clock a minute off would
/// start the meditation a minute out of sync with the world. Every pause
/// response carries `serverNow`; syncing keeps a running offset so `now`
/// tracks the server without ever touching the device clock.
///
/// Dev builds can pin `debugOverride` to force any phase; the same instant is
/// forwarded to the server as `X-Debug-Now` (see `APIClient.debugNowProvider`)
/// so server-side gating agrees with what the UI shows.
@MainActor
@Observable
final class SyncedClock {
  /// serverNow − deviceNow at the last sync.
  private(set) var serverOffset: TimeInterval = 0

  /// Dev-only frozen "now". Ignored outside dev builds.
  var debugOverride: Date? {
    didSet { if !AppConfig.current.isDev { debugOverride = nil } }
  }

  var now: Date { debugOverride ?? Date().addingTimeInterval(serverOffset) }

  /// `now − deviceNow`, covering both the server correction and a pinned
  /// debug clock — what `CountdownView.clockOffset` wants.
  var effectiveOffset: TimeInterval { now.timeIntervalSinceNow }

  func sync(serverNow: Date) {
    // When the clock is pinned for debugging, the server echoes the pinned
    // time back — folding that into the offset would corrupt real time.
    guard debugOverride == nil else { return }
    serverOffset = serverNow.timeIntervalSinceNow
  }

  /// Value for the `X-Debug-Now` request header; nil everywhere but a pinned
  /// dev clock, so release traffic never carries it.
  var debugHeaderValue: String? {
    guard AppConfig.current.isDev, let debugOverride else { return nil }
    return ISO8601DateFormatter().string(from: debugOverride)
  }
}
