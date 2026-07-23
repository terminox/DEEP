import SwiftUI
import Observation

/// The user's practice journal: every completed session, and the aggregates
/// the garden grows from. One shared instance is injected by the shell so a
/// session finished anywhere — Garden, Deep Sound, Global Pause — lands in the
/// same journal.
@MainActor
protocol PracticeStore: AnyObject, Observable {
  var completions: [PracticeCompletion] { get }
  /// The gentle daily goal, in minutes.
  var dailyGoalMinutes: Int { get }
  var minutesToday: Int { get }
  var currentStreakDays: Int { get }
  var longestStreakDays: Int { get }

  /// Records a finished session locally and quietly offers it to the backend.
  func recordCompletion(of session: DeepSession)
  /// Pushes anything unsynced, then pulls and merges the server's log.
  func refresh() async
  /// Empties the journal — log out and account deletion call this.
  func reset()
}

extension EnvironmentValues {
  /// The shared practice journal. The shell injects the live store; the
  /// default keeps previews hermetic (mirroring `\.heartLedger`).
  @Entry var practiceStore: any PracticeStore = MockPracticeStore()
}
