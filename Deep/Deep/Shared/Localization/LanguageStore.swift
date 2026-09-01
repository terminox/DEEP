import SwiftUI
import Observation

/// The member's language choice, and the one thing that changes it.
///
/// A single enum in `UserDefaults` — deliberately *not* account state, so it
/// survives logging out: the language you read in belongs to the phone in your
/// hand, not to the account signed into it. `AppRootView` reads `selection` to
/// re-key the view tree, and the ambient `Locale.app` / `Bundle.app` read the
/// same stored key so copy resolved outside the view tree agrees with it.
@Observable
final class LanguageStore {
  private(set) var selection: AppLanguage

  /// Injectable for tests only. The ambient accessors always read
  /// `UserDefaults.standard`, so a store pointed at a suite is isolated from
  /// them by design — assert on `selection`, not on `Locale.app`.
  @ObservationIgnored private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    selection = defaults.string(forKey: AppLanguage.defaultsKey)
      .flatMap(AppLanguage.init(rawValue:)) ?? .system
  }

  /// The locale this choice resolves to — the value the view tree is handed as
  /// `\.locale`, and the twin of the ambient `Locale.app`.
  var locale: Locale {
    guard let identifier = selection.localeIdentifier else { return .autoupdatingCurrent }
    return Locale(identifier: identifier)
  }

  /// Adopts a language. Everything downstream keys off `selection`: the view
  /// tree rebuilds, and anything that baked copy in at write time — pending
  /// reminder notifications above all — has to be rebuilt by its own owner.
  func select(_ language: AppLanguage) {
    guard language != selection else { return }
    selection = language
    defaults.set(language.rawValue, forKey: AppLanguage.defaultsKey)
  }
}

// MARK: - Fixtures

extension LanguageStore {
  /// A store on its own preview suite, so fixtures never touch the real choice.
  private static func fixture(_ language: AppLanguage, suite: String) -> LanguageStore {
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.set(language.rawValue, forKey: AppLanguage.defaultsKey)
    return LanguageStore(defaults: defaults)
  }

  /// Following the device — the state almost every preview wants.
  static var preview: LanguageStore {
    fixture(.system, suite: "deep.language.preview")
  }

  /// Pinned to Thai, for previewing a screen's Thai layout.
  static var previewThai: LanguageStore {
    fixture(.thai, suite: "deep.language.preview.thai")
  }
}

extension EnvironmentValues {
  /// The member's language choice. The shell injects the live store; the
  /// default keeps previews hermetic (mirroring `\.continuityWitness`).
  @Entry var languageStore: LanguageStore = .preview
}
