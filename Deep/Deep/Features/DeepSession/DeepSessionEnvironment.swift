import SwiftUI

extension EnvironmentValues {
  /// Launches a guided Deep Session full-screen over the whole shell. Injected
  /// by `MainTabController` into every tab's root view, so any leaf screen can
  /// start a session without knowing who presents it. No-op default keeps
  /// previews hermetic.
  @Entry var startDeepSession: (DeepSession) -> Void = { _ in }
}
