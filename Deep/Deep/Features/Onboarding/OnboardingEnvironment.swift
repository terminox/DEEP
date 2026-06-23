import SwiftUI

extension EnvironmentValues {
  /// Pushes the next onboarding route onto the coordinator's `NavigationPath`.
  /// The coordinator injects the real `path.append`; leaf screens call this from
  /// a plain `Button` instead of hosting a `NavigationLink`, so all routing flows
  /// through the single path. The default is a hermetic no-op for previews.
  @Entry var onboardingAdvance: (OnboardingRoute) -> Void = { _ in }

  /// Marks onboarding finished — the gate in `AppRootView` then crossfades into
  /// the main app. Injected by the coordinator; no-op by default.
  @Entry var onboardingFinish: () -> Void = {}
}
