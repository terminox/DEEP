import SwiftUI

/// The server-driven content that shapes the onboarding flow: the quiz questions
/// and the Mind Trees on offer. The coordinator fetches this once from the
/// backend and injects it through the environment; screens read it from there.
///
/// There is deliberately **no production fallback**. `.fixture` is bundled
/// sample content for previews and `MockOnboardingRemote` only — quietly
/// substituting it for a failed fetch once made a dead backend look like a
/// working one, because the fixture carries the same ids, names and taglines
/// as the real rows and differs only in its artwork. The coordinator holds a
/// real load state instead, and screens rendered without one get `.empty`.
struct OnboardingConfig: Equatable {
  var questions: [QuizQuestion]
  var mindTrees: [MindTree]

  /// No content — what the flow shows before the backend answers.
  static let empty = OnboardingConfig(questions: [], mindTrees: [])

  /// Bundled sample content. Previews and `MockOnboardingRemote` only.
  static let fixture = OnboardingConfig(
    questions: QuizQuestion.all,
    mindTrees: MindTree.all
  )
}

extension EnvironmentValues {
  /// The active onboarding config. Defaults to `.empty`, never the fixture: a
  /// screen rendered outside the coordinator must show nothing rather than
  /// plausible-looking sample trees.
  @Entry var onboardingConfig: OnboardingConfig = .empty
}
