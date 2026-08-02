import Foundation
import Observation

/// The Global Pause clock: device time corrected toward the server's.
///
/// Phase boundaries are shared instants — a device clock a minute off would
/// start the meditation a minute out of sync with the world. Every pause
/// response carries `serverNow`; syncing keeps a running offset so `now`
/// tracks the server without ever touching the device clock. This is also
/// what makes the dev server's time travel work (`scripts/pause-time-travel.sh`):
/// the server reports a pinned `serverNow` and every client simply follows.
@MainActor
@Observable
final class SyncedClock {
  /// serverNow − deviceNow at the last sync.
  private(set) var serverOffset: TimeInterval = 0

  var now: Date { Date().addingTimeInterval(serverOffset) }

  func sync(serverNow: Date) {
    serverOffset = serverNow.timeIntervalSinceNow
  }
}
