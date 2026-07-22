import SwiftUI

extension EnvironmentValues {
  /// Pushes a titled list of collections (a section's "See all" or an Explore
  /// category) onto the Global Pause nav stack. Injected by
  /// `GlobalPauseCoordinatorController`; no-op default keeps previews hermetic.
  /// Collection-detail pushes reuse the shared `openCollection` entry.
  @Entry var openCollectionList: (String, [SoundCollection]) -> Void = { _, _ in }

  /// Opens the Global Pause lobby. Injected by
  /// `GlobalPauseCoordinatorController`; no-op default keeps previews hermetic.
  @Entry var openGlobalPause: () -> Void = {}
}
