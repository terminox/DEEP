import Foundation

/// The ordered steps of the first-run onboarding flow.
///
/// The intro screen is the `NavigationStack` root and is *not* a case here;
/// every other screen is pushed onto the coordinator's `NavigationPath`. Leaf
/// screens advance by calling the injected `onboardingAdvance` action with the
/// next route — they never host a `NavigationLink`.
enum OnboardingRoute: Hashable {
  /// Single-select quiz question at `index` (0-based). The crafting loader
  /// follows the last question.
  case quiz(index: Int)
  /// Gentle "crafting your space" loader; auto-advances when its checklist fills.
  case craftingSpace
  /// Picks the daily pause-reminder time.
  case rhythmPicker
  /// A few personalised recommendation cards (gradient art, never photos).
  case recommendations
  /// Optional "how did you hear about us"; skippable.
  case referral
  /// Choose Email or Sign in with Apple.
  case auth
  /// Email create-account form.
  case emailSignUp
  /// Personalised "Welcome to Deep, {name}" beat.
  case welcome
  /// Soft, dismissable paywall — the last step before the app.
  case paywall
}
