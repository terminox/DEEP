import SwiftUI
import Observation

/// The daily reminder's settings, and the one place that keeps the system's
/// notification queue agreeing with them.
///
/// Local by design: nothing about the nudge reaches the server. It's a
/// property of this phone — the one that will actually buzz — so it survives a
/// log out and does not follow the account to another device.
///
/// The store deliberately doesn't know about practice. Whether today's goal is
/// already met arrives as an argument, so the rule stays testable and the
/// store stays a store.
@Observable
final class ReminderStore {
  private static let key = "deep.reminder"

  private(set) var reminder: DailyReminder
  private(set) var permission: ReminderPermission = .unasked

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let scheduler: any ReminderScheduling
  @ObservationIgnored private let calendar: Calendar
  @ObservationIgnored private let now: () -> Date

  init(
    scheduler: any ReminderScheduling = ReminderScheduler(),
    defaults: UserDefaults = .standard,
    calendar: Calendar = .current,
    now: @escaping () -> Date = Date.init
  ) {
    self.scheduler = scheduler
    self.defaults = defaults
    self.calendar = calendar
    self.now = now
    self.reminder = defaults.data(forKey: Self.key)
      .flatMap { try? JSONDecoder().decode(DailyReminder.self, from: $0) }
      ?? .initial
  }

  /// Picks up the system's answer without prompting. Safe to call on every
  /// foreground: permission can change in iOS Settings while the app sleeps.
  func refreshPermission() async {
    permission = await scheduler.permission()
  }

  /// Turns the reminder on, prompting for permission the first time.
  ///
  /// Returns the settled permission so the screen can explain a refusal rather
  /// than leaving a toggle that silently springs back.
  @discardableResult
  func enable(goalMetToday: Bool) async -> ReminderPermission {
    permission = await scheduler.requestPermission()
    guard permission == .granted else {
      // Never leave the toggle on over a queue that can't exist.
      await write(reminder: DailyReminder(isEnabled: false, hour: reminder.hour, minute: reminder.minute))
      return permission
    }
    await write(reminder: DailyReminder(isEnabled: true, hour: reminder.hour, minute: reminder.minute), goalMetToday: goalMetToday)
    return permission
  }

  func disable() async {
    await write(reminder: DailyReminder(isEnabled: false, hour: reminder.hour, minute: reminder.minute))
  }

  func setTime(_ date: Date, goalMetToday: Bool) async {
    var updated = reminder
    updated.setTime(from: date, calendar: calendar)
    guard updated != reminder else { return }
    await write(reminder: updated, goalMetToday: goalMetToday)
  }

  /// Rebuilds the queue from the current settings.
  ///
  /// Called on every foreground (the window rolls forward, and today's goal
  /// may since have been met) and whenever the language changes, because each
  /// queued notification carries copy that was resolved when it was written.
  func reschedule(goalMetToday: Bool) async {
    guard reminder.isEnabled else {
      await scheduler.clearQueue()
      return
    }
    permission = await scheduler.permission()
    guard permission == .granted else {
      // Permission revoked in Settings while we were away: stop claiming the
      // reminder is on.
      await write(reminder: DailyReminder(isEnabled: false, hour: reminder.hour, minute: reminder.minute))
      return
    }
    await pushQueue(goalMetToday: goalMetToday)
  }

  // MARK: - Internals

  private func write(reminder updated: DailyReminder, goalMetToday: Bool = false) async {
    reminder = updated
    if let data = try? JSONEncoder().encode(updated) {
      defaults.set(data, forKey: Self.key)
    }
    if updated.isEnabled {
      await pushQueue(goalMetToday: goalMetToday)
    } else {
      await scheduler.clearQueue()
    }
  }

  private func pushQueue(goalMetToday: Bool) async {
    let dates = ReminderSchedule.occurrences(
      after: now(),
      reminder: reminder,
      goalMetToday: goalMetToday,
      calendar: calendar
    )
    await scheduler.replaceQueue(
      with: dates.map {
        ReminderOccurrence(date: $0, copy: .forDay(of: $0, calendar: calendar))
      }
    )
  }
}

// MARK: - Fixtures

extension ReminderStore {
  private static func fixture(
    _ reminder: DailyReminder,
    permission: ReminderPermission,
    suite: String
  ) -> ReminderStore {
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    if let data = try? JSONEncoder().encode(reminder) {
      defaults.set(data, forKey: Self.key)
    }
    let store = ReminderStore(
      scheduler: MockReminderScheduler(permission: permission),
      defaults: defaults
    )
    store.permission = permission
    return store
  }

  /// Never switched on — the state the screen opens in for most people.
  static var previewOff: ReminderStore {
    fixture(.initial, permission: .unasked, suite: "deep.reminder.preview.off")
  }

  /// On at 21:00, permission granted.
  static var previewOn: ReminderStore {
    fixture(
      DailyReminder(isEnabled: true, hour: 21, minute: 0),
      permission: .granted,
      suite: "deep.reminder.preview.on"
    )
  }

  /// Refused at some point — the screen has to send them to iOS Settings.
  static var previewDenied: ReminderStore {
    fixture(.initial, permission: .denied, suite: "deep.reminder.preview.denied")
  }
}

extension EnvironmentValues {
  /// The daily reminder's settings. The shell injects the live store; the
  /// default keeps previews hermetic (mirroring `\.continuityWitness`).
  @Entry var reminderStore: ReminderStore = .previewOff
}
