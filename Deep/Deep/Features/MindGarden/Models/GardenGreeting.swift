import Foundation

/// The words the garden opens with — a time-of-day salutation and the day's
/// line of encouragement. A value type with a memberwise init so previews stay
/// hermetic; live callers use `current(on:calendar:)`.
struct GardenGreeting {
  var salutation: String
  var quote: String

  /// Short lines of encouragement, rotated one per day.
  static let quotes: [String] = [
    "Every breath waters your garden.",
    "Small moments grow tall.",
    "You don’t have to rush a tree.",
    "Stillness is how roots deepen.",
    "A little calm, tended daily, becomes shade.",
    "Grow at the pace of breath.",
    "Every oak was once a quiet seed.",
    "Today asks only a few soft minutes."
  ]

  /// The greeting for a given moment: salutation from the hour, quote rotated
  /// deterministically by the day, so it changes daily but holds still all day.
  static func current(on date: Date = .now, calendar: Calendar = .current) -> GardenGreeting {
    let hour = calendar.component(.hour, from: date)
    let salutation = switch hour {
    case 5..<12: "Good morning"
    case 12..<17: "Good afternoon"
    default: "Good evening"
    }
    let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    return GardenGreeting(salutation: salutation, quote: quotes[day % quotes.count])
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
