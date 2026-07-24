import Foundation

/// A shared intention for the pause. `key` is the backend's stable identity
/// (what reflections submit); the label is display copy.
struct Intention: Identifiable, Hashable {
  let key: String
  let label: String

  var id: String { key }

  init(key: String, label: String) {
    self.key = key
    self.label = label
  }

  /// Fixture convenience: derives the key from the label (kebab-case),
  /// matching how the backend seed keys the same options.
  init(label: String) {
    self.init(
      key: label.lowercased().replacingOccurrences(of: " ", with: "-"),
      label: label
    )
  }

  static let samples: [Intention] = [
    Intention(label: "Peace"),
    Intention(label: "Healing"),
    Intention(label: "Gratitude"),
    Intention(label: "Someone I love"),
    Intention(label: "Other")
  ]
}
