import SwiftUI

/// One single-select quiz question. Reads its question from the server-driven
/// `onboardingConfig` by `index` and records the choice before advancing — to
/// the next question, or to the Mind Tree picker after the last. The progress
/// bar lives in the coordinator's persistent chrome, not here.
struct OnboardingQuizView: View {
  let index: Int

  @Environment(\.onboardingStore) private var store
  @Environment(\.onboardingConfig) private var config
  @Environment(\.onboardingAdvance) private var advance

  @State private var selectedOptionID: String?

  private var questions: [QuizQuestion] { config.questions }
  /// Nil only if the config isn't loaded. The coordinator holds the quiz route
  /// until it is, so this is a guard against an empty flow, not a state with a
  /// design of its own.
  private var question: QuizQuestion? {
    questions.indices.contains(index) ? questions[index] : nil
  }
  private var isLast: Bool { index == questions.count - 1 }

  var body: some View {
    ZStack {
      AtmosphereBackground()

      if let question {
        content(for: question)
      }
    }
  }

  private func content(for question: QuizQuestion) -> some View {
    VStack(alignment: .leading, spacing: .rhythm) {
      VStack(alignment: .leading, spacing: .rhythm) {
        Text(question.prompt)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .fixedSize(horizontal: false, vertical: true)

        ScrollView {
          VStack(spacing: 14) {
            ForEach(question.options) { option in
              QuizOptionCard(
                option: option,
                isSelected: selectedOptionID == option.id
              ) {
                select(option, in: question)
              }
            }
          }
        }
        .scrollIndicators(.hidden)
        // Let the frosted cards' soft shadows breathe past the viewport edges.
        .scrollClipDisabled()
      }
      .onboardingContentDrift()

      OnboardingPrimaryButton(title: "Continue", isEnabled: selectedOptionID != nil) {
        advanceFromQuiz()
      }
    }
    .padding(.horizontal, .edge)
    .padding(.bottom, .rhythm)
    .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear { selectedOptionID = store.state.quizAnswers[question.id] }
  }

  private func select(_ option: QuizOption, in question: QuizQuestion) {
    withAnimation(.settle) { selectedOptionID = option.id }
    store.recordAnswer(questionID: question.id, optionID: option.id)
  }

  private func advanceFromQuiz() {
    if isLast {
      advance(.mindTree)
    } else {
      advance(.quiz(index: index + 1))
    }
  }
}

#if DEBUG
#Preview("Onboarding — Quiz") {
  OnboardingQuizView(index: 0)
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
    .environment(\.onboardingConfig, .fixture)
}
#endif
