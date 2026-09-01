import Foundation

/// The words the garden opens with — a time-of-day salutation and the day's
/// line of encouragement. A value type with a memberwise init so previews stay
/// hermetic; live callers use `current(on:calendar:)`.
struct GardenGreeting {
  var salutation: String
  var quote: String

  /// Short lines of encouragement, rotated one per day.
  ///
  /// Computed rather than stored: a `static let` resolves once per process and
  /// would keep serving the language the app launched in.
  static var quotes: [String] {
    [
      String(localized: "Every breath waters your garden.", bundle: .app, locale: .app),
      String(localized: "Small moments grow tall.", bundle: .app, locale: .app),
      String(localized: "You don’t have to rush a tree.", bundle: .app, locale: .app),
      String(localized: "Stillness is how roots deepen.", bundle: .app, locale: .app),
      String(localized: "A little calm, tended daily, becomes shade.", bundle: .app, locale: .app),
      String(localized: "Grow at the pace of breath.", bundle: .app, locale: .app),
      String(localized: "Every oak was once a quiet seed.", bundle: .app, locale: .app),
      String(localized: "Today asks only a few soft minutes.", bundle: .app, locale: .app)
    ]
  }

  /// The greeting for a given moment: salutation from the hour, quote rotated
  /// deterministically by the day, so it changes daily but holds still all day.
  static func current(on date: Date = .now, calendar: Calendar = .current) -> GardenGreeting {
    let hour = calendar.component(.hour, from: date)
    let salutation = switch hour {
    case 5..<12: String(localized: "Good morning", bundle: .app, locale: .app)
    case 12..<17: String(localized: "Good afternoon", bundle: .app, locale: .app)
    default: String(localized: "Good evening", bundle: .app, locale: .app)
    }
    let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    let pool = quotes
    return GardenGreeting(salutation: salutation, quote: pool[day % pool.count])
  }
}

extension GardenGreeting {
  static let sample = GardenGreeting(
    salutation: "Good morning",
    quote: "Every breath waters your garden."
  )

  /// Evening fixture carrying the longest quote, to exercise text wrapping.
  static let evening = GardenGreeting(
    salutation: "Good evening",
    quote: "A little calm, tended daily, becomes shade."
  )
}
