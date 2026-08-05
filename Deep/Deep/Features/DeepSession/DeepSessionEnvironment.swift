import SwiftUI

extension EnvironmentValues {
  /// Pushes the Deep Session threshold (`DeepSessionIntroView`) onto whichever
  /// tab's navigation the entry card lives in. Injected by each tab's
  /// coordinator — `GlobalPauseCoordinatorController`, `DeepSoundCoordinatorView`,
  /// `MindGardenCoordinatorView` — so an entry card never hosts navigation of
  /// its own. The no-op default keeps previews hermetic.
  @Entry var openDeepSession: (DeepSession) -> Void = { _ in }
}
