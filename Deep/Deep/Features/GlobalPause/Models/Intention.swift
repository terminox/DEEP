import Foundation

struct Intention: Identifiable, Hashable {
  let id = UUID()
  let label: String

  static let samples: [Intention] = [
    Intention(label: "Peace"),
    Intention(label: "Healing"),
    Intention(label: "Gratitude"),
    Intention(label: "Someone I love"),
    Intention(label: "Other")
  ]
}
