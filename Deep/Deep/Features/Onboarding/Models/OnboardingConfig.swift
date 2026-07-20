import SwiftUI

/// The server-driven content that shapes the onboarding flow: the quiz questions
/// and the Mind Trees on offer. The coordinator fetches this once from the
/// backend and injects it through the environment; screens read it from there.
/// `.fixture` (the bundled iOS content) is the offline / preview fallback.
struct OnboardingConfig: Equatable {
  var questions: [QuizQuestion]
  var mindTrees: [MindTree]

  static let fixture = OnboardingConfig(
    questions: QuizQuestion.all,
    mindTrees: MindTree.all
  )
}

extension EnvironmentValues {
  /// The active onboarding config. Defaults to the bundled fixtures so previews
  /// and offline launches always have questions to show; the coordinator swaps
  /// in the backend's copy once fetched.
  @Entry var onboardingConfig: OnboardingConfig = .fixture
}
