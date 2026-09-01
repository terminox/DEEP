import Testing
import Foundation
@testable import Deep

/// The store's contract with the system queue: it should never claim the
/// reminder is on over a queue that cannot exist, and every settings change
/// should leave the queue agreeing with the settings.
@Suite("Reminder store")
@MainActor
struct ReminderStoreTests {
  private func makeDefaults(_ name: String) -> UserDefaults {
    let defaults = UserDefaults(suiteName: "deep.tests.\(name)")!
    defaults.removePersistentDomain(forName: "deep.tests.\(name)")
    return defaults
  }

  private var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Bangkok")!
    return c
  }

  private func fixedNow() -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(identifier: "Asia/Bangkok")
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: "2026-09-01T08:00:00+07:00")!
  }

  private func makeStore(
    _ name: String,
    scheduler: MockReminderScheduler
  ) -> ReminderStore {
    ReminderStore(
      scheduler: scheduler,
      defaults: makeDefaults(name),
      calendar: calendar,
      now: fixedNow
    )
  }

  @Test("starts off, with an empty queue")
  func startsOff() async {
    let scheduler = MockReminderScheduler()
    let store = makeStore("starts-off", scheduler: scheduler)
    #expect(store.reminder.isEnabled == false)
    #expect(scheduler.queue.isEmpty)
  }

  @Test("granting permission fills the queue")
  func enableFillsQueue() async {
    let scheduler = MockReminderScheduler(permission: .unasked, grantsWhenAsked: true)
    let store = makeStore("enable-grants", scheduler: scheduler)

    let permission = await store.enable(goalMetToday: false)

    #expect(permission == .granted)
    #expect(store.reminder.isEnabled)
    #expect(scheduler.queue.count == ReminderSchedule.horizon)
  }

  @Test("a refused prompt leaves the toggle off and the queue empty")
  func refusedPermissionLeavesItOff() async {
    let scheduler = MockReminderScheduler(permission: .unasked, grantsWhenAsked: false)
    let store = makeStore("enable-refused", scheduler: scheduler)

    let permission = await store.enable(goalMetToday: false)

    #expect(permission == .denied)
    #expect(store.reminder.isEnabled == false, "never claim it is on over a queue that can't exist")
    #expect(scheduler.queue.isEmpty)
  }

  @Test("switching off clears the queue")
  func disableClearsQueue() async {
    let scheduler = MockReminderScheduler(permission: .granted)
    let store = makeStore("disable", scheduler: scheduler)

    await store.enable(goalMetToday: false)
    #expect(!scheduler.queue.isEmpty)

    await store.disable()
    #expect(store.reminder.isEnabled == false)
    #expect(scheduler.queue.isEmpty)
  }

  @Test("changing the time rewrites the queue to the new hour")
  func timeChangeRewritesQueue() async {
    let scheduler = MockReminderScheduler(permission: .granted)
    let store = makeStore("time-change", scheduler: scheduler)
    await store.enable(goalMetToday: false)

    let sevenThirty = calendar.date(
      bySettingHour: 7, minute: 30, second: 0, of: fixedNow()
    )!
    await store.setTime(sevenThirty, goalMetToday: false)

    #expect(store.reminder.hour == 7)
    #expect(store.reminder.minute == 30)
    for occurrence in scheduler.queue {
      let parts = calendar.dateComponents([.hour, .minute], from: occurrence.date)
      #expect(parts.hour == 7)
      #expect(parts.minute == 30)
    }
  }

  @Test("permission revoked in iOS Settings switches the reminder off")
  func revokedPermissionTurnsItOff() async {
    let scheduler = MockReminderScheduler(permission: .granted)
    let store = makeStore("revoked", scheduler: scheduler)
    await store.enable(goalMetToday: false)
    #expect(store.reminder.isEnabled)

    // Someone turns notifications off for Deep while the app is asleep.
    let revoked = MockReminderScheduler(permission: .denied)
    let reopened = ReminderStore(
      scheduler: revoked,
      defaults: {
        let d = UserDefaults(suiteName: "deep.tests.revoked")!
        return d
      }(),
      calendar: calendar,
      now: fixedNow
    )
    await reopened.reschedule(goalMetToday: false)

    #expect(reopened.reminder.isEnabled == false)
    #expect(revoked.queue.isEmpty)
  }

  @Test("a completed day is dropped from the queue")
  func goalMetDropsToday() async {
    let scheduler = MockReminderScheduler(permission: .granted)
    let store = makeStore("goal-met", scheduler: scheduler)

    await store.enable(goalMetToday: true)

    let today = scheduler.queue.filter { calendar.isDate($0.date, inSameDayAs: fixedNow()) }
    #expect(today.isEmpty)
  }

  @Test("the setting survives a relaunch")
  func settingPersists() async {
    let scheduler = MockReminderScheduler(permission: .granted)
    let store = makeStore("persists", scheduler: scheduler)
    await store.enable(goalMetToday: false)
    let sixAm = calendar.date(bySettingHour: 6, minute: 15, second: 0, of: fixedNow())!
    await store.setTime(sixAm, goalMetToday: false)

    let relaunched = ReminderStore(
      scheduler: MockReminderScheduler(permission: .granted),
      defaults: UserDefaults(suiteName: "deep.tests.persists")!,
      calendar: calendar,
      now: fixedNow
    )
    #expect(relaunched.reminder.isEnabled)
    #expect(relaunched.reminder.hour == 6)
    #expect(relaunched.reminder.minute == 15)
  }
}
