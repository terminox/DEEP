import SwiftUI

extension EnvironmentValues {
  /// Pushes a titled list of collections (a section's "See all" or an Explore
  /// category) onto the Global Pause nav stack. Injected by
  /// `GlobalPauseCoordinatorController`; no-op default keeps previews hermetic.
  /// Collection-detail pushes reuse the shared `openCollection` entry.
  @Entry var openCollectionList: (String, [SoundCollection]) -> Void = { _, _ in }

  /// Pushes Fuku's Lounge onto the Global Pause nav stack. Injected by
  /// `GlobalPauseCoordinatorController`; no-op default keeps previews hermetic.
  @Entry var openFukuLounge: () -> Void = {}

  /// The lounge's radio. The coordinator owns the live one and injects it, so
  /// it can also silence it when the meditation takes the room; the default
  /// here is inert until something calls `join`, and previews replace it with
  /// `MockLoungeRadioPlayer`.
  @Entry var loungeRadio: any LoungeRadioPlaying = LoungeRadioPlayer()
}
