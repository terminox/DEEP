import Foundation

/// One phase of the nightly pause, as absolute instants. The server resolves
/// all wall-clock/timezone math; the client only ever compares dates.
struct PausePhaseWindow: Equatable {
  enum Key: String {
    case lobby, welcome, meditation, feedback
  }

  let key: Key
  let startsAt: Date
  let endsAt: Date
}

/// One Global Pause occurrence, fully resolved: phase instants, event audio,
/// the welcome copy, and the intention options for the feedback phase.
///
/// A day can hold several sessions. The server always resolves exactly one of
/// them — the one under way, else the next — so this stays a single occurrence
/// with four phases, and `nextOccurrenceMeditationStart` says what follows it.
struct PauseSchedule: Equatable {
  let pauseDate: String
  let timezone: String
  let phases: [PausePhaseWindow]
  let lobbyAudioURL: URL?
  /// How long DJ Fuku's lounge set runs, measured server-side off
  /// `lobbyAudioURL`. Zero on a server too old to send it, which reads as
  /// "no set tonight" rather than a broadcast of unknown length.
  let lobbyDuration: TimeInterval
  let meditationAudioURL: URL?
  let meditationDuration: TimeInterval
  /// When the meditation begins in the occurrence *after* this one. Nil on a
  /// server that only ever runs one pause a day — see `nextMeditationStart`.
  var nextOccurrenceMeditationStart: Date? = nil
  let welcomeMessages: [String]
  let intentions: [Intention]

  func window(for key: PausePhaseWindow.Key) -> PausePhaseWindow? {
    phases.first { $0.key == key }
  }

  /// The instant this whole occurrence is over. Nil only for a phase-less
  /// schedule, which is what a server with no sessions configured answers with.
  var windowEnd: Date? {
    phases.map(\.endsAt).max()
  }

  /// The next phase boundary strictly after `date`, or nil once the whole
  /// window has passed (time to re-fetch tomorrow's occurrence).
  func nextBoundary(after date: Date) -> Date? {
    phases
      .flatMap { [$0.startsAt, $0.endsAt] }
      .filter { $0 > date }
      .min()
  }

  /// When the meditation next begins, strictly after `date`: this occurrence's
  /// start while it is still ahead, then the next occurrence the server named.
  ///
  /// The fallback is a 24h projection, and on the server that omits the field
  /// it is exact rather than a guess: only a server running one pause a day
  /// leaves `nextOccurrenceMeditationStart` nil, and there the next occurrence
  /// really is the same wall clock tomorrow. It is the wrong answer on a
  /// multi-session day — twice a day it would point at tomorrow while the next
  /// pause is hours away — which is why the field exists.
  func nextMeditationStart(after date: Date) -> Date? {
    guard let meditation = window(for: .meditation) else { return nil }
    if date < meditation.startsAt { return meditation.startsAt }
    // Guards a server echoing this occurrence's own start, which would leave
    // the countdown target permanently in the past.
    if let next = nextOccurrenceMeditationStart, next > meditation.startsAt { return next }
    return meditation.startsAt.addingTimeInterval(24 * 60 * 60)
  }
}

/// A moment-in-time reading of the live event: who's here and where.
struct PauseLiveSnapshot {
  struct Join: Equatable {
    let iso: String
    let at: Date
    /// Privacy-rounded join coordinates; nil when the server couldn't locate
    /// the IP (the client falls back to the country centroid).
    let lat: Float?
    let lon: Float?
  }

  /// One clustered participant location (server bins nearby people together).
  struct GeoPoint: Equatable {
    let lat: Float
    let lon: Float
    let count: Int
  }

  let serverNow: Date
  let participantCount: Int
  let byCountry: [String: Int]
  /// Tallied by continent code ("AS", "EU", "NA"…) — the reading the live
  /// session names beneath the globe. Wider than `byCountry`: it also holds
  /// people whose device never named a country.
  let byContinent: [String: Int]
  /// Located participants as lat/lon clusters. Empty on older servers —
  /// the globe then falls back to per-country glow from `byCountry`.
  let locations: [GeoPoint]
  /// Participants the server couldn't geolocate, tallied by country. The
  /// client renders these via its country-centroid table.
  let unlocatedByCountry: [String: Int]
  let recentJoins: [Join]
}

/// A join resolved to coordinates (server lat/lon, or the country centroid
/// fallback) — what the globe's spark + ripple pipeline consumes.
struct PauseJoinPoint: Equatable, Sendable {
  let lat: Float
  let lon: Float
}
