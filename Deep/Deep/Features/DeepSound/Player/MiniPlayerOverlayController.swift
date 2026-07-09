import SwiftUI
import UIKit

/// Root the overlay hosts: nothing but the shared player surface, so a UIKit
/// coordinator can float the mini player (and its zoom Now Playing) above an
/// entire navigation stack — the same layering the SwiftUI coordinators get by
/// applying `.playerSurface()` at their root.
struct MiniPlayerOverlayRoot: View {
  let player: any SoundPlaying
  let reportBarFrame: (CGRect?) -> Void

  var body: some View {
    Color.clear
      .playerSurface()
      .environment(\.soundPlayer, player)
      .environment(\.miniPlayerFrameChanged, reportBarFrame)
      .preferredColorScheme(.light)
  }
}

/// Transparent layer that only accepts touches inside the mini bar's reported
/// frame; everything else falls through to the views below. Deterministic —
/// no reliance on the hosting view's private hit-testing.
final class MiniPlayerPassthroughView: UIView {
  /// The bar's frame in window coordinates (SwiftUI `.global` == window space),
  /// or nil while no bar is shown.
  var interactiveFrameInWindow: () -> CGRect? = { nil }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard
      let window,
      let frame = interactiveFrameInWindow(),
      frame.contains(convert(point, to: window))
    else { return nil }
    return super.hitTest(point, with: event)
  }
}

/// Hosts `MiniPlayerOverlayRoot` and remembers the bar's last reported frame
/// for the passthrough view's hit-testing.
final class MiniPlayerOverlayController: UIHostingController<MiniPlayerOverlayRoot> {
  private(set) var miniBarFrameInWindow: CGRect?

  @MainActor
  init(player: any SoundPlaying) {
    super.init(rootView: MiniPlayerOverlayRoot(player: player, reportBarFrame: { _ in }))
    rootView = MiniPlayerOverlayRoot(player: player) { [weak self] frame in
      self?.miniBarFrameInWindow = frame
    }
    view.backgroundColor = .clear
  }

  @available(*, unavailable)
  required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

#if DEBUG
#Preview("Overlay root — playing") {
  MiniPlayerOverlayRoot(player: MockSoundPlayer.playing, reportBarFrame: { _ in })
}

#Preview("Overlay root — idle") {
  MiniPlayerOverlayRoot(player: MockSoundPlayer.idle, reportBarFrame: { _ in })
}
#endif
