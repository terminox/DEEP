import SwiftUI
import Observation

/// The user's practice journal: every completed session, and the aggregates
/// the garden grows from. One shared instance is injected by the shell so a
/// session finished anywhere — Garden, DEEP Sound, Global Pause — lands in the
/// same journal.
///
/// The rhythm (streaks, continuity) counts any practice day — a DEEP Session,
/// a sound listened to its end, a Global Pause the server counted. Minutes and
/// the session cap are DEEP Sessions only.
@MainActor
protocol PracticeStore: AnyObject, Observable {
  var completions: [PracticeCompletion] { get }
  /// The gentle daily goal, in minutes.
  var dailyGoalMinutes: Int { get }
  var minutesToday: Int { get }
  var currentStreakDays: Int { get }
  var longestStreakDays: Int { get }
  /// Whether the server's log has been pulled into this journal at least once
  /// for the signed-in account. Until it has, the rhythm is only what this
  /// install happens to remember — endings hide the continuity beat rather
  /// than show a number that may be wrong.
  var isHydrated: Bool { get }
  /// Whether any finished session is still waiting to reach the server.
  var hasUnsynced: Bool { get }

  /// Records a finished session locally and quietly offers it to the backend.
  func recordCompletion(of session: DeepSession)
  /// Marks a day kept by practice other than a DEEP Session — a track played
  /// to its end, a Global Pause the server counted. Local only: the server
  /// keeps its own record of both and hands it back as `activityDays`.
  func recordActivity(_ kind: PracticeActivity.Kind, at date: Date)
  /// The rhythm before today and as it stands now.
  func continuityTransition() -> ContinuityTransition
  /// Pushes anything unsynced, then pulls and merges the server's log.
  func refresh() async
  /// Returns once the journal is hydrated, or after `timeout` — starting a
  /// pull if none is under way.
  func awaitHydration(timeout: Duration) async
  /// Pushes unsynced sessions, waiting at most `timeout`. True when nothing is
  /// left unsynced.
  func flushPending(timeout: Duration) async -> Bool
  /// Empties the journal — log out and account deletion call this.
  func reset()
}

extension PracticeStore {
  /// Marks a day kept right now.
  func recordActivity(_ kind: PracticeActivity.Kind) {
    recordActivity(kind, at: .now)
  }
}

extension EnvironmentValues {
  /// The shared practice journal. The shell injects the live store; the
  /// default keeps previews hermetic (mirroring `\.heartLedger`).
  @Entry var practiceStore: any PracticeStore = MockPracticeStore()
}
