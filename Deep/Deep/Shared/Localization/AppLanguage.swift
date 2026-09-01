import Foundation

// MARK: - The choice

/// The language Deep reads its copy in.
///
/// `system` follows the device's own preference; the other cases override it
/// in-app, so a member whose phone is set to English can still read Deep in
/// Thai without changing anything about their phone.
enum AppLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
  /// Follow whatever the device asks for, falling back to English.
  case system
  case english
  case thai

  var id: String { rawValue }
}

extension AppLanguage {
  /// Where the choice lives. The ambient `Locale.app` / `Bundle.app` read the
  /// same key, so copy resolved outside the view tree — notifications,
  /// formatters, the UIKit tab bar — lands in the same language as the screen
  /// behind it.
  static let defaultsKey = "deep.language"

  /// The choice currently stored on this device. `nonisolated` because copy is
  /// resolved from every isolation domain the app has; `UserDefaults` reads are
  /// thread-safe and served from an in-process cache, so this stays cheap
  /// enough to call once per string.
  nonisolated static var current: AppLanguage {
    guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
          let language = AppLanguage(rawValue: raw)
    else { return .system }
    return language
  }

  /// BCP-47 identifier for formatting dates, numbers and lists. Nil when the
  /// device decides.
  var localeIdentifier: String? {
    switch self {
    case .system: nil
    case .english: "en-US"
    case .thai: "th"
    }
  }

  /// The `.lproj` this language's copy compiles into. Nil when the device
  /// decides, in which case the main bundle's own preferred-localization
  /// resolution is already the right answer.
  var bundleLanguageCode: String? {
    switch self {
    case .system: nil
    case .english: "en"
    case .thai: "th"
    }
  }

  /// The `Accept-Language` header this choice should send.
  ///
  /// BCP-47 with hyphens, which is what the header wants — `Locale.identifier`
  /// is not a substitute, since it renders as `en_US`. Following the device
  /// forwards the device's own ranked list so the server negotiates against
  /// the same preferences iOS would.
  var acceptLanguageHeader: String {
    if let identifier = localeIdentifier { return identifier }
    let preferred = Locale.preferredLanguages.prefix(3)
    guard !preferred.isEmpty else { return "en-US" }
    return preferred
      .enumerated()
      .map { index, tag in index == 0 ? tag : "\(tag);q=\(String(format: "%.1f", 1.0 - Double(index) * 0.1))" }
      .joined(separator: ", ")
  }

  /// The language's name in its own language — the one label that reads right
  /// whichever language the picker happens to be showing. Only `system` is
  /// translated, because only `system` is a sentence rather than a name.
  var endonym: String {
    switch self {
    case .system: String(localized: "Match my device", bundle: .app, locale: .app)
    case .english: "English"
    case .thai: "ไทย"
    }
  }
}

// MARK: - Ambient projections

extension Locale {
  /// The locale Deep formats and resolves copy in: `Locale.current` filtered
  /// through the in-app language choice.
  ///
  /// Read this rather than `.current` anywhere a member sees the result — a
  /// date, a duration, a compact number, a region name. `.current` would
  /// silently follow the device and disagree with the language they picked.
  nonisolated static var app: Locale {
    guard let identifier = AppLanguage.current.localeIdentifier else {
      return .autoupdatingCurrent
    }
    return Locale(identifier: identifier)
  }
}

extension Bundle {
  /// The bundle Deep resolves its String Catalog against.
  ///
  /// `.main` when the device decides; otherwise that language's compiled
  /// `.lproj`, so `String(localized:bundle:locale:)` outside a view body
  /// matches the screen around it. Foundation uniques `Bundle(path:)` per
  /// path, so repeated lookups return the same instance rather than re-reading
  /// the filesystem.
  nonisolated static var app: Bundle {
    guard let code = AppLanguage.current.bundleLanguageCode,
          let path = Bundle.main.path(forResource: code, ofType: "lproj"),
          let bundle = Bundle(path: path)
    else { return .main }
    return bundle
  }
}
