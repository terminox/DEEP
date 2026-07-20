import SwiftUI

/// One single-select quiz question. Reads its question from `QuizQuestion.all`
/// by `index`, shows the top progress bar, and records the choice before
/// advancing — to the next question, or to the Mind Tree picker after the last.
struct OnboardingQuizView: View {
  let index: Int

  @Environment(\.onboardingStore) private var store
  @Environment(\.onboardingConfig) private var config
  @Environment(\.onboardingAdvance) private var advance

  @State private var selectedOptionID: String?

  private var questions: [QuizQuestion] { config.questions }
  private var question: QuizQuestion { questions[index] }
  /// The Mind Tree picker counts as the flow's final step, so progress reads
  /// "1 of 3", "2 of 3" here and completes at "3 of 3" on that screen.
  private var totalSteps: Int { questions.count + 1 }
  private var isLast: Bool { index == questions.count - 1 }

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(alignment: .leading, spacing: .rhythm) {
        OnboardingProgressBar(
          progress: Double(index + 1) / Double(totalSteps),
          fractionLabel: "\(index + 1) of \(totalSteps)"
        )
        .padding(.top, 8)

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
          .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)

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

#Preview("Onboarding — Quiz") {
  OnboardingQuizView(index: 0)
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
}
