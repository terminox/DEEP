import Foundation

/// One selectable answer in the onboarding quiz. `palette` colours a small
/// gradient swatch beside the label, in keeping with DESIGN.md's "gradients,
/// never photography" rule.
struct QuizOption: Identifiable, Hashable {
  let id: String
  let title: String
  var subtitle: String? = nil
  let palette: ArtworkPalette
}

/// A single-select onboarding question. The prompt is phrased in Deep's gentle,
/// second-person present-tense voice — an invitation, never a demand.
struct QuizQuestion: Identifiable, Hashable {
  let id: String
  let prompt: String
  let options: [QuizOption]
}

extension QuizQuestion {
  /// The two questions, phrased in Deep's emotional-wellness domain
  /// (pause · breathe · connect · heal). The Mind Tree picker follows as the
  /// flow's third and final step.
  static let all: [QuizQuestion] = [
    QuizQuestion(
      id: "arrival",
      prompt: "What brings you here today?",
      options: [
        QuizOption(id: "slow-down", title: "To slow down", palette: .tide),
        QuizOption(id: "clarity", title: "To find clarity", palette: .mist),
        QuizOption(id: "recharge", title: "To recharge", palette: .ember),
        QuizOption(id: "exploring", title: "Just exploring", palette: .bloom),
      ]
    ),
    QuizQuestion(
      id: "longing",
      prompt: "What do you long for right now?",
      options: [
        QuizOption(id: "calm", title: "Calm", palette: .tide),
        QuizOption(id: "connection", title: "Connection", palette: .dusk),
        QuizOption(id: "clarity", title: "Clarity", palette: .mist),
        QuizOption(id: "healing", title: "Healing", palette: .bloom),
      ]
    ),
  ]
}
