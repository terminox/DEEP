import Foundation

// MARK: - The choice

/// The language Deep reads its copy in.
///
/// Deep matches the device by default — that is behaviour, not a setting, so
/// there is no "follow the system" case to pick. Choosing one of these pins it
/// in-app, so a member whose phone is set to English can still read Deep in
/// Thai without changing anything about their phone.
enum AppLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
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

  /// The language the device is asking for, narrowed to the two Deep speaks.
  ///
  /// `preferredLocalizations` is iOS's own answer: it ranks the device's
  /// language preferences against the localizations actually in the bundle, so
  /// a phone set to French lands on English without a case for it here.
  nonisolated static var deviceMatched: AppLanguage {
    Bundle.main.preferredLocalizations.first?.hasPrefix("th") == true ? .thai : .english
  }

  /// The language this device reads in: the pinned choice if there is one, the
  /// device's own otherwise. `nonisolated` because copy is resolved from every
  /// isolation domain the app has; `UserDefaults` reads are thread-safe and
  /// served from an in-process cache, so this stays cheap enough to call once
  /// per string.
  nonisolated static var current: AppLanguage {
    guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
          let language = AppLanguage(rawValue: raw)
    else { return deviceMatched }
    return language
  }

  /// BCP-47 identifier for formatting dates, numbers and lists.
  var localeIdentifier: String {
    switch self {
    case .english: "en-US"
    case .thai: "th"
    }
  }

  /// The `.lproj` this language's copy compiles into.
  var bundleLanguageCode: String {
    switch self {
    case .english: "en"
    case .thai: "th"
    }
  }

  /// The `Accept-Language` header this language should send.
  ///
  /// BCP-47 with hyphens, which is what the header wants — `Locale.identifier`
  /// is not a substitute, since it renders as `en_US`.
  var acceptLanguageHeader: String { localeIdentifier }

  /// The language's name in its own language — the one label that reads right
  /// whichever language the picker happens to be showing, and the reason
  /// neither of these is a String Catalog key.
  var endonym: String {
    switch self {
    case .english: "English"
    case .thai: "ไทย"
    }
  }
}

// MARK: - Ambient projections

extension Locale {
  /// The locale Deep formats and resolves copy in: the language this device
  /// reads in, rather than the one the phone is set to.
  ///
  /// Read this rather than `.current` anywhere a member sees the result — a
  /// date, a duration, a compact number, a region name. `.current` would
  /// silently follow the device and disagree with the language they picked.
  nonisolated static var app: Locale {
    Locale(identifier: AppLanguage.current.localeIdentifier)
  }
}

extension Bundle {
  /// The bundle Deep resolves its String Catalog against.
  ///
  /// The reading language's compiled `.lproj`, so
  /// `String(localized:bundle:locale:)` outside a view body matches the screen
  /// around it. Foundation uniques `Bundle(path:)` per path, so repeated
  /// lookups return the same instance rather than re-reading the filesystem.
  nonisolated static var app: Bundle {
    guard let path = Bundle.main.path(forResource: AppLanguage.current.bundleLanguageCode, ofType: "lproj"),
          let bundle = Bundle(path: path)
    else { return .main }
    return bundle
  }
}
