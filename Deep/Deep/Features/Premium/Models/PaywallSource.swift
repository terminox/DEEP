import SwiftUI

/// Which door the paywall was opened from.
///
/// It tailors the subhead, and nothing else. The headline is the product's
/// name on every door, and what DEEP Premium includes doesn't change with
/// where you were standing when you asked. One screen, several ways in.
enum PaywallSource: String, Identifiable, Hashable {
  /// The "Upgrade to DEEP Premium" row in Settings.
  case settings
  /// A locked sound, reached from a collection or the playlist.
  case lockedSound
  /// The premium step during onboarding.
  case onboarding

  var id: String { rawValue }

  var subhead: LocalizedStringKey {
    switch self {
    case .settings:
      return "Every sound, every session — yours whenever you need them."
    case .lockedSound:
      return "It's part of DEEP Premium, along with everything else in the library."
    case .onboarding:
      return "Try DEEP Premium free for seven days. Nothing to decide today."
    }
  }
}

extension EnvironmentValues {
  /// Raises the paywall from whichever door was opened. The coordinator injects
  /// the real presentation; a leaf screen calls it from a plain `Button`, so
  /// routing stays in one place. The default is a no-op that keeps previews
  /// hermetic.
  @Entry var openPaywall: (PaywallSource) -> Void = { _ in }
}
