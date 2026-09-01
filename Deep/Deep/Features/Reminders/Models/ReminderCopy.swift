import Foundation

/// The words a reminder arrives with.
///
/// Rotated one per day the way `GardenGreeting` rotates its quotes, so eight
/// weeks of queued notifications don't read as the same sentence repeating.
/// The voice follows `DESIGN.md`: an invitation, never a demand — nothing here
/// says you missed anything, owe anything, or broke anything.
struct ReminderCopy: Equatable, Sendable {
  var title: String
  var body: String
}

extension ReminderCopy {
  /// Resolved through `Bundle.app` / `Locale.app` rather than the device's
  /// language, so a member reading Deep in Thai on an English phone is
  /// reminded in Thai.
  ///
  /// A computed property, never a `static let`: a stored one would resolve
  /// once per process and then keep serving the language the app happened to
  /// launch in.
  static var pool: [ReminderCopy] {
    [
      ReminderCopy(
        title: String(localized: "A few soft minutes", bundle: .app, locale: .app),
        body: String(localized: "Your garden is here whenever you are.", bundle: .app, locale: .app)
      ),
      ReminderCopy(
        title: String(localized: "Time to breathe", bundle: .app, locale: .app),
        body: String(localized: "Nothing to catch up on. Just a breath.", bundle: .app, locale: .app)
      ),
      ReminderCopy(
        title: String(localized: "Still here", bundle: .app, locale: .app),
        body: String(localized: "A quiet moment, if you'd like one.", bundle: .app, locale: .app)
      ),
      ReminderCopy(
        title: String(localized: "Somewhere to rest", bundle: .app, locale: .app),
        body: String(localized: "Small moments grow tall.", bundle: .app, locale: .app)
      ),
      ReminderCopy(
        title: String(localized: "A pause is waiting", bundle: .app, locale: .app),
        body: String(localized: "Stillness is how roots deepen.", bundle: .app, locale: .app)
      ),
      ReminderCopy(
        title: String(localized: "Whenever you're ready", bundle: .app, locale: .app),
        body: String(localized: "You don't have to rush a tree.", bundle: .app, locale: .app)
      ),
      ReminderCopy(
        title: String(localized: "Your garden is open", bundle: .app, locale: .app),
        body: String(localized: "Every breath waters it.", bundle: .app, locale: .app)
      )
    ]
  }

  /// The line for a given day — deterministic, so a queued notification reads
  /// the same whenever the queue is rebuilt.
  static func forDay(of date: Date, calendar: Calendar = .current) -> ReminderCopy {
    let pool = pool
    let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    return pool[day % pool.count]
  }
}
