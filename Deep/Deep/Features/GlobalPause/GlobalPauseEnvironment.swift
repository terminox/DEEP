import SwiftUI

extension EnvironmentValues {
  /// Routes a tapped home item to the coordinator, which pushes the detail
  /// screen. No-op default keeps previews hermetic.
  @Entry var openHomeItem: (HomeItem) -> Void = { _ in }

  /// Opens the Global Pause lobby. Injected by
  /// `GlobalPauseCoordinatorController`; no-op default keeps previews hermetic.
  @Entry var openGlobalPause: () -> Void = {}
}
