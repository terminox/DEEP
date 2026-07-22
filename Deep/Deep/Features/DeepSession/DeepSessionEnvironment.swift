import SwiftUI
import UIKit

/// Launches a guided Deep Session full-screen over the whole shell. Injected by
/// `MainTabController` into every tab's root view, so any leaf screen can start
/// a session without knowing who presents it.
///
/// The optional anchor is the UIKit view backing the tapped control (captured
/// via `zoomTransitionAnchor(_:)`); the shell zooms the session out of its
/// frame. Without an anchor the session still presents, just without the morph.
struct StartDeepSessionAction {
  /// The shell-provided presentation. The no-op default keeps previews hermetic.
  var launch: (DeepSession, UIView?) -> Void = { _, _ in }

  func callAsFunction(_ session: DeepSession, from anchor: UIView? = nil) {
    launch(session, anchor)
  }
}

extension EnvironmentValues {
  @Entry var startDeepSession = StartDeepSessionAction()
}
