import Foundation

/// A shared intention for the pause. `key` is the backend's stable identity
/// (what reflections submit); the label is display copy.
///
/// The two are deliberately independent. An earlier convenience initialiser
/// derived the key by kebab-casing the label — which quietly made the wire
/// format a function of the English wording, so translating "Someone I love"
/// would have started submitting `someone-i-love` in Thai characters. Keys are
/// written out; labels are translated.
struct Intention: Identifiable, Hashable {
  let key: String
  let label: String

  var id: String { key }

  init(key: String, label: String) {
    self.key = key
    self.label = label
  }

  /// The offline fixture set, mirroring the backend seed's keys exactly.
  ///
  /// Computed rather than stored: a `static let` would resolve its copy once
  /// per process and keep serving the language the app launched in.
  static var samples: [Intention] {
    [
      Intention(key: "peace", label: String(localized: "Peace", bundle: .app, locale: .app)),
      Intention(key: "healing", label: String(localized: "Healing", bundle: .app, locale: .app)),
      Intention(key: "gratitude", label: String(localized: "Gratitude", bundle: .app, locale: .app)),
      Intention(
        key: "someone-i-love",
        label: String(localized: "Someone I love", bundle: .app, locale: .app)
      ),
      Intention(key: "other", label: String(localized: "Other", bundle: .app, locale: .app))
    ]
  }
}
