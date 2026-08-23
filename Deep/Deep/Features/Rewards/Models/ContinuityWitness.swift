import SwiftUI
import Observation

/// Remembers the day the continuity beat was last witnessed, so the rhythm is
/// noticed once a day across every practice: a Deep Session and a Global Pause
/// on the same day share the one moment rather than each claiming it.
///
/// A single `Date` in `UserDefaults` — the day it falls on is the whole state,
/// read through the device's own calendar so the boundary follows the member's
/// timezone (the `HeartLedger.heartsEarnedToday` pattern).
@MainActor
@Observable
final class ContinuityWitness {
  private static let key = "deep.continuity.witness"

  /// The last day the rhythm was witnessed; nil before the first one.
  private var lastWitnessed: Date?

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let calendar: Calendar
  @ObservationIgnored private let now: () -> Date

  init(
    defaults: UserDefaults = .standard,
    calendar: Calendar = .current,
    now: @escaping () -> Date = Date.init
  ) {
    self.defaults = defaults
    self.calendar = calendar
    self.now = now
    lastWitnessed = defaults.object(forKey: Self.key) as? Date
  }

  /// Whether today's beat has already been shown. Derived rather than stored,
  /// so a session left open past midnight reads false on its own — no timer.
  var hasWitnessedToday: Bool {
    guard let lastWitnessed else { return false }
    return calendar.isDate(lastWitnessed, inSameDayAs: now())
  }

  /// Stamps today. Called as the continuity screen appears — not when the
  /// ritual is composed — so an ending the member walks away from doesn't
  /// spend the day's one witnessing.
  func witnessToday() {
    guard !hasWitnessedToday else { return }
    let today = now()
    lastWitnessed = today
    defaults.set(today, forKey: Self.key)
  }

  /// Forgets the signed-out account's day, so the next account's first
  /// practice meets its own rhythm. Log out and account deletion call this.
  func resetLocalState() {
    lastWitnessed = nil
    defaults.removeObject(forKey: Self.key)
  }
}

// MARK: - Fixtures

extension ContinuityWitness {
  /// Seeds a known day without touching the real stamp — fixture factories
  /// and tests start from a decided state through this.
  func seed(lastWitnessed day: Date?) {
    lastWitnessed = day
    if let day {
      defaults.set(day, forKey: Self.key)
    } else {
      defaults.removeObject(forKey: Self.key)
    }
  }

  /// A witness on its own preview suite, so fixtures never touch the real day.
  private static func fixture(lastWitnessed day: Date?, suite: String) -> ContinuityWitness {
    let witness = ContinuityWitness(defaults: UserDefaults(suiteName: suite) ?? .standard)
    witness.seed(lastWitnessed: day)
    return witness
  }

  /// A day whose rhythm hasn't been noticed yet — the full ritual runs.
  static var unwitnessed: ContinuityWitness {
    fixture(lastWitnessed: nil, suite: "deep.continuity.preview")
  }

  /// A day an earlier practice already witnessed — the beat rests.
  static var witnessed: ContinuityWitness {
    fixture(lastWitnessed: .now, suite: "deep.continuity.preview.witnessed")
  }
}

extension EnvironmentValues {
  /// The shared day-stamp behind the continuity beat. The shell injects the
  /// live witness; the default keeps previews hermetic (mirroring
  /// `\.gardenStore`).
  @Entry var continuityWitness: ContinuityWitness = .unwitnessed
}
