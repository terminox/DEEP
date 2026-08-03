import SwiftUI

extension EnvironmentValues {
  /// Appends the next onboarding route to the coordinator's route stack. Leaf
  /// screens call this from a plain `Button`, so all routing flows through the
  /// coordinator's single stack (which also drives the calm hush transition
  /// and the persistent chrome). The default is a hermetic no-op for previews.
  @Entry var onboardingAdvance: (OnboardingRoute) -> Void = { _ in }

  /// Marks onboarding finished — the gate in `AppRootView` then crossfades into
  /// the main app. Injected by the coordinator; no-op by default.
  @Entry var onboardingFinish: () -> Void = {}

  /// Which way the coordinator last routed, so each screen's content block can
  /// drift in the matching direction (forward rises in from below; going back
  /// it sinks out the way it came). Injected by the coordinator.
  @Entry var onboardingNavDirection: SoftDriftTransition.Direction = .forward
}
