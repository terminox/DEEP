import SwiftUI

/// One single-select quiz question. Reads its question from `QuizQuestion.all`
/// by `index`, shows the top progress bar, and records the choice before
/// advancing — to the next question, or to the crafting loader after the last.
struct OnboardingQuizView: View {
  let index: Int

  @Environment(\.onboardingStore) private var store
  @Environment(\.onboardingAdvance) private var advance

  @State private var selectedOptionID: String?

  private var question: QuizQuestion { QuizQuestion.all[index] }
  private var total: Int { QuizQuestion.all.count }
  private var isLast: Bool { index == total - 1 }

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(alignment: .leading, spacing: .rhythm) {
        OnboardingProgressBar(
          progress: Double(index + 1) / Double(total),
          fractionLabel: "\(index + 1) of \(total)"
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

        OnboardingPrimaryButton(title: isLast ? "See my space" : "Next", isEnabled: selectedOptionID != nil) {
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
      advance(.craftingSpace)
    } else {
      advance(.quiz(index: index + 1))
    }
  }
}

#Preview("Onboarding — Quiz") {
  OnboardingQuizView(index: 0)
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
}
