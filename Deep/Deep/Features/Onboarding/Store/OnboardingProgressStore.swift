import SwiftUI
import Observation

/// The onboarding flow's state surface. Screens depend on this protocol rather
/// than the concrete defaults-backed store, so they preview against an in-memory
/// `MockOnboardingStore` with no persistence side effects. It refines
/// `Observable` so SwiftUI tracks changes through the `any OnboardingProgressStore`
/// existential.
protocol OnboardingProgressStore: AnyObject, Observable {
  var state: OnboardingState { get }
  var hasCompletedOnboarding: Bool { get }

  func recordAnswer(questionID: String, optionID: String)
  /// Records the chosen Mind Tree (persisted; the Mind Garden reads it later).
  func recordMindTree(_ id: String?)
  /// Marks onboarding finished — flips the gate that reveals the main app.
  func completeOnboarding()
  /// Replaces local state with a server-fetched profile (used after log-in so a
  /// returning user's completed onboarding is reflected locally).
  func hydrate(quizAnswers: [String: String], mindTree: String?, completed: Bool)
  /// Clears all progress so the flow can be replayed (debug aid).
  func reset()
}

extension OnboardingProgressStore {
  var hasCompletedOnboarding: Bool { state.hasCompletedOnboarding }
}

extension EnvironmentValues {
  /// The onboarding state store. `AppRootView` injects the real instance; the
  /// default keeps previews and the gate working without ceremony.
  @Entry var onboardingStore: any OnboardingProgressStore = OnboardingProgressDefaultsStore()
}
