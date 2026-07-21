import Foundation

/// The ordered steps of the first-run onboarding flow.
///
/// The welcome screen is the coordinator's resting state (an empty route
/// stack) and is *not* a case here; every other screen is appended to the
/// coordinator's route stack. Leaf screens advance by calling the injected
/// `onboardingAdvance` action with the next route — routing never leaves the
/// coordinator.
enum OnboardingRoute: Hashable {
  /// Single-select quiz question at `index` (0-based). The Mind Tree picker
  /// follows the last question.
  case quiz(index: Int)
  /// Choose a Mind Tree — the last choice before creating an account.
  case mindTree
  /// Create an account (email/password) — new users, after the Mind Tree.
  case signUp
  /// Log in — returning users, reached from the welcome screen.
  case logIn
  /// Gentle "shaping your space" loader; syncs onboarding to the backend and
  /// finishes when its checklist fills.
  case craftingSpace
}
