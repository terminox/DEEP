import AVFoundation
import Foundation

/// The footage that plays in Fuku's Lounge. Four ambient loops follow the
/// member's own hour; the intro is the one that opens the nightly broadcast,
/// and the only one that carries sound.
enum FukuClip: String, CaseIterable {
  case morning, afternoon, night, midnight, intro

  /// Bundle resource name. Resources land flat in the bundle root, so these
  /// have to stay unique app-wide.
  var resource: String { "fuku_\(rawValue)" }

  /// The ambient clip for a moment, read off the *device's* clock — the lounge
  /// shows a member their own time of day, not Bangkok's, so the room looks
  /// like the hour they're actually in.
  ///
  /// The first two bands are `GardenGreeting`'s salutation hours (5..<12,
  /// 12..<17) so the two never disagree about what part of the day it is; the
  /// evening is split into night and a genuinely late midnight.
  static func ambient(at date: Date = .now, calendar: Calendar = .current) -> FukuClip {
    switch calendar.component(.hour, from: date) {
    case 5..<12: .morning
    case 12..<17: .afternoon
    case 17..<24: .night
    default: .midnight
    }
  }

  /// How long the intro runs, read from the bundled clip itself. The set is
  /// intro-then-music, so this is where the handoff falls — and reading it off
  /// the file keeps it from drifting the way a typed constant does the first
  /// time the footage is recut. Zero when the resource is missing (previews
  /// against a stripped bundle), which the broadcast reads as "no intro".
  static func introDuration() async -> TimeInterval {
    guard let url = Bundle.main.url(forResource: FukuClip.intro.resource, withExtension: "mp4"),
          let duration = try? await AVURLAsset(url: url).load(.duration)
    else { return 0 }
    let seconds = CMTimeGetSeconds(duration)
    return seconds.isFinite && seconds > 0 ? seconds : 0
  }
}

/// DJ Fuku's nightly set, as instants: it opens at the top of the lobby phase
/// with the intro clip playing aloud, hands off to the lounge track, and signs
/// off when the track runs out.
///
/// It is a broadcast, not a playlist — every stage is derived from one clock, so
/// two people who walk into the lounge a minute apart are hearing the same bar,
/// and a latecomer joins mid-track rather than starting it over.
struct LoungeBroadcast: Equatable {
  enum Stage: Equatable {
    case off
    /// The intro clip, `elapsed` seconds in, playing with its own sound.
    case intro(elapsed: TimeInterval)
    /// The lounge track, `offset` seconds in, under the ambient hero clip.
    case music(offset: TimeInterval)
  }

  let startsAt: Date
  let introDuration: TimeInterval
  let trackDuration: TimeInterval
  /// Where the set is cut off whatever it has left to play: the welcome phase,
  /// which belongs to the pause itself. A longer track uploaded into an
  /// untouched window can shorten Fuku's set, but never talk over the countdown.
  let hardStop: Date

  var endsAt: Date {
    min(startsAt.addingTimeInterval(introDuration + trackDuration), hardStop)
  }

  func stage(at date: Date) -> Stage {
    guard date >= startsAt, date < endsAt else { return .off }
    let elapsed = date.timeIntervalSince(startsAt)
    return elapsed < introDuration
      ? .intro(elapsed: elapsed)
      : .music(offset: elapsed - introDuration)
  }

  /// The stage at `date` given that the intro clip has just reported its own
  /// end. AVFoundation and the clock disagree by a few milliseconds about when
  /// that is, and on the wrong side of the difference `stage(at:)` would answer
  /// "still the intro" for a clip that has stopped playing and will never
  /// report an end again — leaving the set becalmed on a frozen last frame.
  func stageAfterIntro(at date: Date) -> Stage {
    guard date < endsAt else { return .off }
    let elapsed = max(date.timeIntervalSince(startsAt), introDuration)
    return .music(offset: elapsed - introDuration)
  }

  func isOnAir(at date: Date) -> Bool { stage(at: date) != .off }
}

extension PauseSchedule {
  /// Tonight's set, or nil when there is nothing to broadcast — no lobby phase,
  /// no track, or a server too old to send the track's length.
  func loungeBroadcast(introDuration: TimeInterval) -> LoungeBroadcast? {
    guard let lobby = window(for: .lobby), lobbyAudioURL != nil, lobbyDuration > 0
    else { return nil }
    return LoungeBroadcast(
      startsAt: lobby.startsAt,
      introDuration: introDuration,
      trackDuration: lobbyDuration,
      hardStop: lobby.endsAt
    )
  }
}
