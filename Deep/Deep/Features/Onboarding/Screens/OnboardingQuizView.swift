import SwiftUI

/// One single-select quiz question. Reads its question from `QuizQuestion.all`
/// by `index` and records the choice before advancing — to the next question,
/// or to the Mind Tree picker after the last. The progress bar lives in the
/// coordinator's persistent chrome, not here.
struct OnboardingQuizView: View {
  let index: Int

  @Environment(\.onboardingStore) private var store
  @Environment(\.onboardingConfig) private var config
  @Environment(\.onboardingAdvance) private var advance

  @State private var selectedOptionID: String?

  private var questions: [QuizQuestion] { config.questions }
  private var question: QuizQuestion { questions[index] }
  private var isLast: Bool { index == questions.count - 1 }

  var body: some View {
    ZStack {
      AtmosphereBackground()

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
                  select(option)
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
    }
    .onAppear { selectedOptionID = store.state.quizAnswers[question.id] }
  }

  private func select(_ option: QuizOption) {
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
}
#endif
