import SwiftUI

/// The build environment the app was compiled for. Backed by the `AppEnvironment`
/// Info.plist key, which each `.xcconfig` (Dev/Staging/Pilot/Prod) sets.
enum AppEnvironment: String {
  case dev
  case staging
  case pilot
  case prod

  /// Human label for diagnostics / a debug badge.
  var label: String {
    switch self {
    case .dev: return "Dev"
    case .staging: return "Staging"
    case .pilot: return "Pilot"
    case .prod: return "Prod"
    }
  }
}

/// The legal documents a subscription screen has to link. App Review rejects a
/// paywall without them, so they travel the same `.xcconfig` → `Info.plist`
/// pipeline as `apiBaseURL` rather than being written into a view.
struct LegalLinks: Equatable, Sendable {
  var terms: URL
  var privacy: URL

  /// The values this build currently ships, and the environment default —
  /// unlike a fixture, a missed injection must still link somewhere real.
  static let placeholder = LegalLinks(
    terms: URL(string: "https://deep.app/terms")!,
    privacy: URL(string: "https://deep.app/privacy")!
  )
}

/// Read-only, typed projection of the per-environment build configuration.
///
/// Values arrive from the active `.xcconfig` → `Config/Info.plist` (`APIBaseURL`,
/// `AppEnvironment`, `TermsURL`, `PrivacyURL`) and are read once at launch. This
/// mirrors the `DeepTheme` token pattern: one source of truth, surfaced as
/// first-class typed values — never a bag of stringly-typed lookups scattered
/// across the app.
struct AppConfig {
  let environment: AppEnvironment
  let apiBaseURL: URL
  let legal: LegalLinks

  /// The configuration baked into this build. Injected at the composition roots.
  static let current = AppConfig()

  init(bundle: Bundle = .main) {
    let env = (bundle.object(forInfoDictionaryKey: "AppEnvironment") as? String) ?? "dev"
    self.environment = AppEnvironment(rawValue: env) ?? .dev

    // Fall back to local dev if the key is somehow missing, so the app never
    // launches with an unusable base URL.
    self.apiBaseURL = Self.url(bundle, "APIBaseURL")
      ?? URL(string: "http://localhost:8080")!

    // Same reasoning, one step stronger: a dead legal link is an App Review
    // rejection, so a missing key degrades to the URL this build ships.
    self.legal = LegalLinks(
      terms: Self.url(bundle, "TermsURL") ?? LegalLinks.placeholder.terms,
      privacy: Self.url(bundle, "PrivacyURL") ?? LegalLinks.placeholder.privacy
    )
  }

  /// An Info.plist string read as a URL. xcconfig values are unquoted, so a
  /// trailing space would otherwise become part of the value.
  private static func url(_ bundle: Bundle, _ key: String) -> URL? {
    guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
    return URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  /// True only for the local `dev` build — used to surface debug affordances.
  var isDev: Bool { environment == .dev }
}

/// The sentences that carry the legal links, as tappable markdown.
///
/// They live beside `LegalLinks` rather than inside any one feature because
/// onboarding and the paywall must link the same two documents — and because
/// the alternative is what was here before: a markdown literal interpolated
/// straight into `LocalizedStringKey.init(_:)`, which extracts no key at all
/// and so can never be translated.
enum LegalCopy {
  /// Onboarding's line, where following through *is* the agreement.
  static func agreement(_ links: LegalLinks, locale: Locale) -> AttributedString {
    markdown(
      String(
        localized: "By continuing, you agree to our [Terms](\(links.terms.absoluteString)) and [Privacy Policy](\(links.privacy.absoluteString)).",
        bundle: .localized(for: locale),
        locale: locale,
        comment: "Onboarding footer. The placeholders are URLs — keep the [text](url) markdown intact."
      )
    )
  }

  /// The paywall's line, which invites rather than binds.
  static func invitation(_ links: LegalLinks, locale: Locale) -> AttributedString {
    markdown(
      String(
        localized: "Read our [Terms](\(links.terms.absoluteString)) and [Privacy Policy](\(links.privacy.absoluteString)).",
        bundle: .localized(for: locale),
        locale: locale,
        comment: "Paywall footer. The placeholders are URLs — keep the [text](url) markdown intact."
      )
    )
  }

  /// Falls back to the raw sentence rather than losing the words: a translator
  /// dropping a bracket costs the links, not the paragraph.
  private static func markdown(_ string: String) -> AttributedString {
    (try? AttributedString(markdown: string)) ?? AttributedString(string)
  }
}

extension EnvironmentValues {
  /// The two documents a subscription screen must link.
  ///
  /// The default is the shipping placeholder rather than an empty fixture: a
  /// screen that somehow renders outside the composition root should still link
  /// somewhere real. Previews override it explicitly to stay hermetic.
  @Entry var legalLinks: LegalLinks = .placeholder
}
