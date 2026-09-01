import Foundation
import UserNotifications

/// Whether this device will let Deep speak up.
enum ReminderPermission: Equatable, Sendable {
  /// Never asked. The prompt is still available.
  case unasked
  case granted
  /// Refused, or switched off later in iOS Settings. Asking again does
  /// nothing — only Settings can undo it, so the UI has to say so.
  case denied
}

/// One queued nudge: when it fires and what it says. The copy is resolved when
/// the occurrence is built, not when it fires, which is why the whole queue is
/// rebuilt on a language change.
struct ReminderOccurrence: Equatable, Sendable {
  var date: Date
  var copy: ReminderCopy
}

/// Putting the daily nudge on the system's calendar. Named for the capability
/// so the real one and the test double can both be honest about what they are.
protocol ReminderScheduling: Sendable {
  func permission() async -> ReminderPermission
  /// Prompts if the system will still prompt; returns the settled state either
  /// way.
  func requestPermission() async -> ReminderPermission
  /// Replaces Deep's whole reminder queue with exactly these occurrences.
  func replaceQueue(with occurrences: [ReminderOccurrence]) async
  func clearQueue() async
  /// Identifiers currently queued — the seam QA and tests read the result from.
  func queuedIdentifiers() async -> [String]
}

// MARK: - The real one

/// Backs the reminder with `UNUserNotificationCenter`.
///
/// Deep asks only for `.alert` and `.sound` — no badge, because a count on the
/// icon is a debt display, and nothing here is owed.
struct ReminderScheduler: ReminderScheduling {
  /// Every request Deep owns carries this prefix, so replacing the queue never
  /// touches a notification some other feature scheduled later.
  static let identifierPrefix = "deep.reminder."

  private var center: UNUserNotificationCenter { .current() }

  func permission() async -> ReminderPermission {
    switch await center.notificationSettings().authorizationStatus {
    case .notDetermined: .unasked
    case .denied: .denied
    case .authorized, .provisional, .ephemeral: .granted
    @unknown default: .unasked
    }
  }

  func requestPermission() async -> ReminderPermission {
    let current = await permission()
    // `requestAuthorization` on an already-denied app resolves instantly to
    // false without showing anything; calling it would just look like a
    // silent failure.
    guard current == .unasked else { return current }
    let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    return granted ? .granted : .denied
  }

  func replaceQueue(with occurrences: [ReminderOccurrence]) async {
    await clearQueue()
    let calendar = Calendar.current
    for occurrence in occurrences {
      let content = UNMutableNotificationContent()
      // Plain strings, already resolved through `Bundle.app`. Deliberately not
      // `NSString.localizedUserNotificationString(forKey:)`, which re-resolves
      // at delivery time against the *device* language and would quietly
      // ignore the in-app picker.
      content.title = occurrence.copy.title
      content.body = occurrence.copy.body
      content.sound = .default
      content.interruptionLevel = .passive

      let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: occurrence.date)
      let request = UNNotificationRequest(
        identifier: Self.identifier(for: occurrence.date, calendar: calendar),
        content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
      )
      try? await center.add(request)
    }
  }

  func clearQueue() async {
    let ours = await queuedIdentifiers()
    center.removePendingNotificationRequests(withIdentifiers: ours)
  }

  func queuedIdentifiers() async -> [String] {
    await center.pendingNotificationRequests()
      .map(\.identifier)
      .filter { $0.hasPrefix(Self.identifierPrefix) }
  }

  /// One identifier per calendar day, so a rebuild replaces a day's nudge
  /// rather than stacking a second one on it.
  static func identifier(for date: Date, calendar: Calendar = .current) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(
      format: "%@%04d-%02d-%02d",
      identifierPrefix,
      parts.year ?? 0,
      parts.month ?? 0,
      parts.day ?? 0
    )
  }
}

// MARK: - Test double

/// Records what it was asked to do instead of doing it, so previews stay
/// hermetic and tests can assert on the queue.
final class MockReminderScheduler: ReminderScheduling, @unchecked Sendable {
  private let lock = NSLock()
  private var _permission: ReminderPermission
  private var _queue: [ReminderOccurrence] = []
  /// Whether a prompt would be granted, for exercising the denied path.
  var grantsWhenAsked: Bool

  init(permission: ReminderPermission = .unasked, grantsWhenAsked: Bool = true) {
    self._permission = permission
    self.grantsWhenAsked = grantsWhenAsked
  }

  var queue: [ReminderOccurrence] {
    lock.withLock { _queue }
  }

  func permission() async -> ReminderPermission {
    lock.withLock { _permission }
  }

  func requestPermission() async -> ReminderPermission {
    lock.withLock {
      guard _permission == .unasked else { return _permission }
      _permission = grantsWhenAsked ? .granted : .denied
      return _permission
    }
  }

  func replaceQueue(with occurrences: [ReminderOccurrence]) async {
    lock.withLock { _queue = occurrences }
  }

  func clearQueue() async {
    lock.withLock { _queue = [] }
  }

  func queuedIdentifiers() async -> [String] {
    lock.withLock { _queue.map { ReminderScheduler.identifier(for: $0.date) } }
  }
}
