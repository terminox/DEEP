import Foundation

/// Everything the onboarding flow gathers, persisted as one small Codable blob.
///
/// Quiz answers are kept as a flat `questionID -> optionID` map so adding or
/// reordering questions never breaks decoding of an older saved state.
struct OnboardingState: Codable, Equatable {
  var hasCompletedOnboarding: Bool = false
  var quizAnswers: [String: String] = [:]
  /// The chosen Mind Tree id (e.g. "oak"). Persisted now — the Mind Garden will
  /// read it later. Optional, so older saved states decode with `nil`.
  var mindTree: String? = nil
}

extension OnboardingState {
  /// A clean first-run state. `nonisolated` so it can be used as a default
  /// argument from any isolation (the project defaults to MainActor isolation).
  nonisolated static let fresh = OnboardingState()
}
