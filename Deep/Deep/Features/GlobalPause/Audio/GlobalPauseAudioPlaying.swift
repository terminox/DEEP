import Foundation
import Observation

/// What the Global Pause event is doing with sound right now.
enum GlobalPauseAudioMode: Equatable {
  case idle
  /// The theme loop that holds the lobby (and, softly, the feedback phase).
  case lobbyLoop
  /// The live meditation stream. Deliberately unpausable — see
  /// `GlobalPauseAudioPlaying`'s contract.
  case meditation
}

/// The audio surface of a Global Pause — a deliberately smaller contract than
/// `SoundPlaying`.
///
/// There is no pause, no seek, no transport of any kind: the meditation is a
/// live, shared event, and the only way out is leaving the lobby. Keeping those
/// affordances off the protocol makes "cannot be paused" true by construction
/// rather than by UI discipline. The shared `SoundPlaying` player is paused on
/// lobby entry and never sees this audio, so the mini player never surfaces it.
///
/// It refines `Observable` so SwiftUI tracks changes through the
/// `any GlobalPauseAudioPlaying` existential, mirroring `SoundPlaying`.
@MainActor
protocol GlobalPauseAudioPlaying: AnyObject, Observable {
  var mode: GlobalPauseAudioMode { get }
  /// Seconds into the meditation stream (0 outside meditation mode).
  var meditationElapsed: TimeInterval { get }

  /// Recovery seam: after an interruption or stall the player re-seeks to
  /// whatever offset this returns — the session owner wires it to
  /// "synced now − meditation start" so recovery lands back on the live edge.
  var meditationOffsetProvider: (() -> TimeInterval)? { get set }

  /// Streams the lobby theme on an endless loop.
  func playLobbyLoop(url: URL, volume: Float)
  /// Ramps the loop's volume (used for the soft return in the feedback phase
  /// and the fade under the welcome → meditation handoff).
  func setLobbyVolume(_ volume: Float, fadeDuration: TimeInterval)
  /// Joins the meditation stream `offset` seconds in. A latecomer whose offset
  /// is already past `duration` gets silence — the phase math has moved on.
  func playMeditation(url: URL, startingAt offset: TimeInterval, duration: TimeInterval)
  /// Re-seeks the meditation stream to the live edge (interruption recovery,
  /// clock corrections).
  func realignMeditation(to offset: TimeInterval)
  /// Tears everything down. Idempotent — called from both the close action and
  /// the lobby's dismissal safety net.
  func stop()
}
