import Foundation
import Observation

/// What Fuku's Lounge is doing with sound right now.
enum LoungeRadioState: Equatable {
  case off
  /// The set is on air. `isMuted` is the member's own choice, made by tapping
  /// the ON AIR pill — the broadcast keeps running underneath either way, so
  /// unmuting rejoins it live rather than resuming where it was silenced.
  case onAir(isMuted: Bool)
}

/// The lounge's radio: one track, joined at an offset, mutable, stoppable.
///
/// Deliberately smaller than `SoundPlaying` and shaped differently from
/// `GlobalPauseAudioPlaying`. There is no scrub and no skip — you cannot move
/// around inside a broadcast — but unlike the meditation, which refuses every
/// transport control to make "cannot be paused" true by construction, this one
/// is happy to be silenced. It is background music in a room, not a sit.
///
/// It refines `Observable` so SwiftUI tracks changes through the
/// `any LoungeRadioPlaying` existential, mirroring the other two players.
@MainActor
protocol LoungeRadioPlaying: AnyObject, Observable {
  var state: LoungeRadioState { get }

  /// Recovery seam: after an interruption or a stall the player re-seeks to
  /// whatever offset this returns, so it lands back on the live edge instead of
  /// resuming a broadcast everyone else has moved past. Nil resumes in place.
  var liveOffsetProvider: (() -> TimeInterval)? { get set }

  /// Joins the set `offset` seconds in. Calling it again with the same URL and
  /// a nearby offset is a no-op, so a re-render can't restart the track.
  func join(url: URL, at offset: TimeInterval)
  /// Silences or unsilences the set without leaving it.
  func setMuted(_ muted: Bool)
  /// Tears everything down. Idempotent — called from the lounge's disappearance
  /// and from the coordinator when the meditation takes the room.
  func stop()
}
