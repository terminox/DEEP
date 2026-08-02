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

/// Tonight's Global Pause, fully resolved: phase instants, event audio, the
/// welcome copy, and the intention options for the feedback phase.
struct PauseSchedule: Equatable {
  let pauseDate: String
  let timezone: String
  let phases: [PausePhaseWindow]
  let lobbyAudioURL: URL?
  let meditationAudioURL: URL?
  let meditationDuration: TimeInterval
  let welcomeMessages: [String]
  let intentions: [Intention]

  func window(for key: PausePhaseWindow.Key) -> PausePhaseWindow? {
    phases.first { $0.key == key }
  }

  /// The next phase boundary strictly after `date`, or nil once the whole
  /// window has passed (time to re-fetch tomorrow's occurrence).
  func nextBoundary(after date: Date) -> Date? {
    phases
      .flatMap { [$0.startsAt, $0.endsAt] }
      .filter { $0 > date }
      .min()
  }

  /// When the meditation next begins: tonight's start, or — once tonight is
  /// over — a 24h projection. The projection is only a countdown target; the
  /// real next occurrence arrives with the post-window schedule re-fetch.
  func nextMeditationStart(after date: Date) -> Date {
    guard let meditation = window(for: .meditation) else { return date }
    if date < meditation.startsAt { return meditation.startsAt }
    return meditation.startsAt.addingTimeInterval(24 * 60 * 60)
  }
}

/// A moment-in-time reading of the live event: who's here and where.
struct PauseLiveSnapshot {
  struct Join: Equatable {
    let iso: String
    let at: Date
  }

  let serverNow: Date
  let participantCount: Int
  let byCountry: [String: Int]
  let recentJoins: [Join]
}
