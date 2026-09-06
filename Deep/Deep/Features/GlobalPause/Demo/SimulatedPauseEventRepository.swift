#if DEBUG
import Foundation

/// The Global Pause backend, with a demo standing in front of it.
///
/// Disarmed it forwards every call untouched, so a Dev build behaves exactly as
/// it always did. Armed it answers the schedule and the live snapshot itself —
/// an always-open meditation window and a `SimulatedCrowd` of whatever size the
/// director is showing — while still forwarding the peace-message feed, so the
/// lounge and its composer keep working against the real server.
///
/// Decorating rather than replacing is what makes the toggle possible at all:
/// `AppDependencies` is built once at launch and never rebuilt, so a
/// swap-at-construction design would have forced a relaunch for every tier
/// change.
@MainActor
final class SimulatedPauseEventRepository: PauseEventRepository {
  private let upstream: any PauseEventRepository
  private let clock: SyncedClock
  private let director: PauseDemoDirector

  /// When the last simulated poll ran, so each snapshot's arrivals cover the
  /// window since the previous one rather than an invented span.
  private var lastPolledAt: Date?

  init(
    forwardingTo upstream: any PauseEventRepository,
    clock: SyncedClock,
    director: PauseDemoDirector = .shared
  ) {
    self.upstream = upstream
    self.clock = clock
    self.director = director
  }

  // MARK: - Simulated while armed

  /// An always-open meditation, so the session can be entered at any hour in
  /// any timezone with no server, no Mac and no VPN.
  ///
  /// This is not a parallel mechanism to `scripts/pause-time-travel.sh` — that
  /// remains the only way to exercise the *real* repository, and it needs a dev
  /// server reachable from the phone. This is the same code path the fixture
  /// already uses, pointed at now instead of 20:40 Bangkok.
  func schedule() async throws -> PauseSchedule {
    guard director.isEnabled else { return try await upstream.schedule() }
    let now = Date()
    clock.sync(serverNow: now)
    let start = director.meditationStart(at: now)
    let duration = PauseDemoDirector.meditationDuration

    return PauseSchedule(
      pauseDate: now.formatted(.iso8601.year().month().day()),
      timezone: TimeZone.current.identifier,
      phases: [
        PausePhaseWindow(
          key: .lobby,
          startsAt: start.addingTimeInterval(-duration),
          endsAt: start.addingTimeInterval(-10)
        ),
        PausePhaseWindow(
          key: .welcome,
          startsAt: start.addingTimeInterval(-10),
          endsAt: start
        ),
        PausePhaseWindow(
          key: .meditation,
          startsAt: start,
          endsAt: start.addingTimeInterval(duration)
        ),
        PausePhaseWindow(
          key: .feedback,
          startsAt: start.addingTimeInterval(duration),
          endsAt: start.addingTimeInterval(duration * 2)
        ),
      ],
      lobbyAudioURL: nil,
      lobbyDuration: 0,
      // Nil on purpose: a demo held in a meeting room should not stream ten
      // minutes of audio off a dev host. `armCompletion(offset:)` falls back to
      // the wall clock, which carries the session's timing on its own.
      meditationAudioURL: nil,
      meditationDuration: duration,
      welcomeMessages: [],
      intentions: Intention.samples
    )
  }

  func live() async throws -> PauseLiveSnapshot {
    guard director.isEnabled else { return try await upstream.live() }
    let now = Date()
    clock.sync(serverNow: now)
    // First poll of a visit has no previous window; one poll interval is the
    // honest span for it.
    let since = lastPolledAt ?? now.addingTimeInterval(-5)
    lastPolledAt = now
    return SimulatedCrowd(participantCount: director.participantCount)
      .snapshot(serverNow: now, joinsSince: since)
  }

  /// Nil leaves `enterSession()`'s locale-centroid seeding standing, so the
  /// globe turns to wherever the demo phone actually is rather than to a
  /// server-resolved address it has no way to know.
  @discardableResult
  func heartbeat(presenceID: String, countryISO: String?) async throws -> PauseJoinPoint? {
    guard director.isEnabled else {
      return try await upstream.heartbeat(presenceID: presenceID, countryISO: countryISO)
    }
    return nil
  }

  func leave(presenceID: String) async {
    guard director.isEnabled else {
      await upstream.leave(presenceID: presenceID)
      return
    }
    lastPolledAt = nil
  }

  // MARK: - Always the real thing

  // The peace feed is real even in demo mode: it is the part of the lounge a
  // stakeholder can meaningfully read, and nothing about it scales with the
  // participant count.

  func messages(limit: Int, cursor: String?) async throws -> PeaceMessagesPage {
    try await upstream.messages(limit: limit, cursor: cursor)
  }

  func postMessage(
    _ text: String,
    countryISO: String?,
    intention: String?
  ) async throws -> PostedPeaceMessage {
    try await upstream.postMessage(text, countryISO: countryISO, intention: intention)
  }

  func submitReflection(intention: String?, mood: String?) async throws {
    try await upstream.submitReflection(intention: intention, mood: mood)
  }
}
#endif
