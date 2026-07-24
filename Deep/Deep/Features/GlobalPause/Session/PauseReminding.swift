import SwiftUI
import Observation
import UserNotifications

/// The "notify me before the pause" capability behind `NextPauseCard`'s bell.
/// UI depends on the protocol so previews stay free of notification prompts.
@MainActor
protocol PauseReminding: AnyObject, Observable {
  var isEnabled: Bool { get }
  /// Returns the state that actually took effect — enabling can come back
  /// false when notification permission is denied.
  @discardableResult
  func setEnabled(_ enabled: Bool) async -> Bool
}

/// Schedules the real daily reminder: one repeating local notification at the
/// lobby's opening wall-clock time in Bangkok, where the pause lives. A stable
/// identifier keeps re-enabling idempotent.
@MainActor
@Observable
final class LocalPauseReminder: PauseReminding {
  private static let identifier = "global-pause-daily"
  private static let defaultsKey = "pause.notifyEnabled"

  private(set) var isEnabled: Bool

  init() {
    isEnabled = UserDefaults.standard.bool(forKey: Self.defaultsKey)
  }

  @discardableResult
  func setEnabled(_ enabled: Bool) async -> Bool {
    let center = UNUserNotificationCenter.current()

    guard enabled else {
      center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
      persist(false)
      return false
    }

    let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    guard granted else {
      persist(false)
      return false
    }

    let content = UNMutableNotificationContent()
    content.title = "Global Pause"
    content.body = "The world is gathering. Tonight's pause is about to begin."
    content.sound = .default

    // 20:30 in the pause's home timezone — every device fires at the same
    // world instant regardless of where it is.
    var components = DateComponents()
    components.hour = 20
    components.minute = 30
    components.timeZone = TimeZone(identifier: "Asia/Bangkok")

    let request = UNNotificationRequest(
      identifier: Self.identifier,
      content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    )
    try? await center.add(request)
    persist(true)
    return true
  }

  private func persist(_ enabled: Bool) {
    isEnabled = enabled
    UserDefaults.standard.set(enabled, forKey: Self.defaultsKey)
  }
}

#if DEBUG
/// Preview fake: flips state in memory, never touches notification APIs.
@MainActor
@Observable
final class MockPauseReminder: PauseReminding {
  var isEnabled: Bool

  init(isEnabled: Bool = false) {
    self.isEnabled = isEnabled
  }

  @discardableResult
  func setEnabled(_ enabled: Bool) async -> Bool {
    isEnabled = enabled
    return enabled
  }
}
#endif

extension EnvironmentValues {
  /// The pause reminder. Real by default (it is inert until toggled);
  /// previews inject `MockPauseReminder` for full hermeticity.
  @Entry var pauseReminder: any PauseReminding = LocalPauseReminder()
}
