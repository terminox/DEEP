import SwiftUI

extension EnvironmentValues {
  /// Selects the Sounds tab — the one navigation action that crosses tabs
  /// rather than pushing within one, so the shell owns it where a coordinator
  /// owns the rest. Injected by `MainTabController`; no-op default keeps
  /// previews hermetic.
  @Entry var openDeepSound: () -> Void = {}
}
