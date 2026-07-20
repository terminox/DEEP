import Foundation

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

/// Read-only, typed projection of the per-environment build configuration.
///
/// Values arrive from the active `.xcconfig` → `Config/Info.plist` (`APIBaseURL`,
/// `AppEnvironment`) and are read once at launch. This mirrors the `DeepTheme`
/// token pattern: one source of truth, surfaced as first-class typed values —
/// never a bag of stringly-typed lookups scattered across the app.
struct AppConfig {
  let environment: AppEnvironment
  let apiBaseURL: URL

  /// The configuration baked into this build. Injected at the composition roots.
  static let current = AppConfig()

  init(bundle: Bundle = .main) {
    let env = (bundle.object(forInfoDictionaryKey: "AppEnvironment") as? String) ?? "dev"
    self.environment = AppEnvironment(rawValue: env) ?? .dev

    let raw = (bundle.object(forInfoDictionaryKey: "APIBaseURL") as? String) ?? ""
    // Fall back to local dev if the key is somehow missing, so the app never
    // launches with an unusable base URL.
    self.apiBaseURL =
      URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))
      ?? URL(string: "http://localhost:8080")!
  }

  /// True only for the local `dev` build — used to surface debug affordances.
  var isDev: Bool { environment == .dev }
}
