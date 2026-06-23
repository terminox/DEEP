import Foundation

/// Everything the onboarding flow gathers, persisted as one small Codable blob.
///
/// Quiz answers are kept as a flat `questionID -> optionID` map so adding or
/// reordering questions never breaks decoding of an older saved state. The
/// daily pause time stores only hour/minute (the calendar date is irrelevant —
/// it's a recurring reminder).
struct OnboardingState: Codable, Equatable {
  var hasCompletedOnboarding: Bool = false
  var quizAnswers: [String: String] = [:]
  var dailyPauseTime: DateComponents? = nil
  var referralSource: String? = nil
}

extension OnboardingState {
  /// A clean first-run state. `nonisolated` so it can be used as a default
  /// argument from any isolation (the project defaults to MainActor isolation).
  nonisolated static let fresh = OnboardingState()
}
