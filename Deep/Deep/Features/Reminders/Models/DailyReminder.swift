import Foundation

/// The daily nudge's whole settings state: whether it's on, and what time of
/// day it arrives. Persisted as one JSON blob, matching how every other local
/// store in the app keeps its state.
struct DailyReminder: Codable, Equatable, Sendable {
  var isEnabled: Bool
  var hour: Int
  var minute: Int

  /// Off, at 21:00. The hour is deliberate: the nightly Global Pause runs at
  /// 20:40 Bangkok, and a nudge landing on top of it would be asking someone
  /// to practise while they already are.
  static let initial = DailyReminder(isEnabled: false, hour: 21, minute: 0)
}

extension DailyReminder {
  /// The time of day, as the calendar wants it.
  var time: DateComponents {
    DateComponents(hour: hour, minute: minute)
  }

  /// Today's occurrence, for a `DatePicker` to bind to. The date part is
  /// meaningless — only the clock face is being chosen.
  func pickerDate(calendar: Calendar = .current, now: Date = .now) -> Date {
    calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
  }

  /// Adopts the clock face of a picked date, discarding its day.
  mutating func setTime(from date: Date, calendar: Calendar = .current) {
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    hour = parts.hour ?? hour
    minute = parts.minute ?? minute
  }
}
