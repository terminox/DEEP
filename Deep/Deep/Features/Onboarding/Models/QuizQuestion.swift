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
  /// The six questions, re-themed from the Calm "sleep plan" quiz to Deep's
  /// emotional-wellness domain (pause · breathe · connect · heal).
  static let all: [QuizQuestion] = [
    QuizQuestion(
      id: "weighing",
      prompt: "What's been weighing on you lately?",
      options: [
        QuizOption(id: "stress", title: "Stress and overwhelm", palette: .ember),
        QuizOption(id: "loneliness", title: "Loneliness", palette: .dusk),
        QuizOption(id: "restlessness", title: "A restless mind", palette: .mist),
        QuizOption(id: "grief", title: "Grief or heaviness", palette: .tide),
        QuizOption(id: "nothing", title: "Nothing in particular", palette: .bloom),
      ]
    ),
    QuizQuestion(
      id: "longing",
      prompt: "When you pause, what do you long for?",
      options: [
        QuizOption(id: "calm", title: "Calm", palette: .tide),
        QuizOption(id: "connection", title: "Connection", palette: .dusk),
        QuizOption(id: "clarity", title: "Clarity", palette: .mist),
        QuizOption(id: "healing", title: "Healing", palette: .bloom),
      ]
    ),
    QuizQuestion(
      id: "difficult-feelings",
      prompt: "How do you usually meet difficult feelings?",
      options: [
        QuizOption(id: "sit", title: "I sit with them", palette: .tide),
        QuizOption(id: "distract", title: "I distract myself", palette: .ember),
        QuizOption(id: "push", title: "I push them away", palette: .mist),
        QuizOption(id: "unsure", title: "I'm still learning how", palette: .aurora),
      ]
    ),
    QuizQuestion(
      id: "gentleness",
      prompt: "Where would a little more gentleness help?",
      options: [
        QuizOption(id: "self", title: "How I speak to myself", palette: .bloom),
        QuizOption(id: "rest", title: "Letting myself rest", palette: .tide),
        QuizOption(id: "others", title: "My patience with others", palette: .dusk),
        QuizOption(id: "body", title: "Listening to my body", palette: .ember),
      ]
    ),
    QuizQuestion(
      id: "good-day",
      prompt: "What does a good day feel like to you?",
      options: [
        QuizOption(id: "steady", title: "Steady and unhurried", palette: .mist),
        QuizOption(id: "present", title: "Present and awake", palette: .aurora),
        QuizOption(id: "warm", title: "Warm and connected", palette: .dusk),
        QuizOption(id: "light", title: "Light and free", palette: .bloom),
      ]
    ),
    QuizQuestion(
      id: "company",
      prompt: "How would you like Deep to keep you company?",
      options: [
        QuizOption(id: "sounds", title: "Soothing sounds", palette: .tide),
        QuizOption(id: "pauses", title: "Shared moments of pause", palette: .dusk),
        QuizOption(id: "growth", title: "A quiet sense of growth", palette: .bloom),
        QuizOption(id: "all", title: "A little of everything", palette: .aurora),
      ]
    ),
  ]
}
