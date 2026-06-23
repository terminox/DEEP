#if DEBUG
import Foundation
import Observation

/// In-memory `OnboardingProgressStore` for previews and tests — no persistence,
/// no side effects. Use the static fixtures for the common cases.
@MainActor
@Observable
final class MockOnboardingStore: OnboardingProgressStore {
  private(set) var state: OnboardingState

  init(state: OnboardingState = .fresh) {
    self.state = state
  }

  func recordAnswer(questionID: String, optionID: String) {
    state.quizAnswers[questionID] = optionID
  }

  func setDailyPauseTime(_ time: DateComponents) {
    state.dailyPauseTime = time
  }

  func setReferralSource(_ source: String?) {
    state.referralSource = source
  }

  func completeOnboarding() {
    state.hasCompletedOnboarding = true
  }

  func reset() {
    state = .fresh
  }
}

extension MockOnboardingStore {
  /// A clean first run.
  static var fresh: MockOnboardingStore { MockOnboardingStore() }

  /// A couple of answers already recorded, partway through the quiz.
  static var midQuiz: MockOnboardingStore {
    MockOnboardingStore(
      state: OnboardingState(quizAnswers: ["weighing": "stress", "longing": "calm"])
    )
  }
}
#endif
