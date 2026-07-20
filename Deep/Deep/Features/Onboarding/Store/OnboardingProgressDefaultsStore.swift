import Foundation
import Observation

/// `OnboardingProgressStore` backed by a single JSON blob in `UserDefaults`.
///
/// The whole `OnboardingState` is encoded under one key on every mutation, so
/// there are no per-field keys to keep in sync and a partially-completed flow
/// survives relaunch. Decoding tolerates older saved shapes because
/// `OnboardingState` only ever adds optional fields.
@MainActor
@Observable
final class OnboardingProgressDefaultsStore: OnboardingProgressStore {
  private static let key = "deep.onboarding.state"

  private(set) var state: OnboardingState {
    didSet { persist() }
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: Self.key),
       let decoded = try? JSONDecoder().decode(OnboardingState.self, from: data) {
      state = decoded
    } else {
      state = .fresh
    }
  }

  func recordAnswer(questionID: String, optionID: String) {
    state.quizAnswers[questionID] = optionID
  }

  func recordMindTree(_ id: String?) {
    state.mindTree = id
  }

  func completeOnboarding() {
    state.hasCompletedOnboarding = true
  }

  func hydrate(quizAnswers: [String: String], mindTree: String?, completed: Bool) {
    state = OnboardingState(
      hasCompletedOnboarding: completed,
      quizAnswers: quizAnswers,
      mindTree: mindTree
    )
  }

  func reset() {
    state = .fresh
  }

  private func persist() {
    guard let data = try? JSONEncoder().encode(state) else { return }
    defaults.set(data, forKey: Self.key)
  }
}
