import Foundation

/// The ordered steps of the first-run onboarding flow.
///
/// The welcome screen is the `NavigationStack` root and is *not* a case here;
/// every other screen is pushed onto the coordinator's `NavigationPath`. Leaf
/// screens advance by calling the injected `onboardingAdvance` action with the
/// next route — they never host a `NavigationLink`.
enum OnboardingRoute: Hashable {
  /// Single-select quiz question at `index` (0-based). The Mind Tree picker
  /// follows the last question.
  case quiz(index: Int)
  /// Choose a Mind Tree — the last choice before the space is shaped.
  case mindTree
  /// Gentle "shaping your space" loader; finishes onboarding when its
  /// checklist fills.
  case craftingSpace
}
