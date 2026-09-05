import Foundation

/// The Global Pause card's resting line: "Today · 8:10 AM".
///
/// Rendered in the **member's own timezone**, not the pause's. The schedule
/// payload carries a `timezone`, but that is the zone the sessions are written
/// in and the day the awards key on — it is not the zone anyone reads the card
/// in. With sessions placed across the day so that people outside Asia get one
/// at a sane local hour, a Bangkok wall clock would make exactly those sessions
/// unreadable to exactly the people they were added for.
///
/// Deriving a zone *name* from the payload is no help either, so there is no
/// suffix at all: `Asia/Bangkok` localizes to "Indochina Time" or "GMT+7",
/// both worse copy than the "Thailand Time" this replaces. Two members in
/// different zones seeing different numbers for the same instant is correct.
///
/// Pure, and free of any clock of its own, so the day word can be tested
/// without waiting for one.
enum PauseScheduleLine {
  static func text(
    target: Date,
    now: Date,
    calendar: Calendar = .autoupdatingCurrent,
    timeZone: TimeZone = .autoupdatingCurrent,
    locale: Locale = .app
  ) -> String {
    let time = target.formatted(
      Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
    )
    var dayCalendar = calendar
    dayCalendar.timeZone = timeZone
    // The server never resolves further ahead than the next calendar day, so
    // two words cover it. (A late Bangkok session read from a UTC+14 device can
    // technically land the day after tomorrow; reading "Tomorrow" there is a
    // rounding error, not a third case anyone will meet.)
    return dayCalendar.isDate(target, inSameDayAs: now)
      ? String(localized: "Today · \(time)", bundle: .app, locale: .app)
      : String(localized: "Tomorrow · \(time)", bundle: .app, locale: .app)
  }
}
