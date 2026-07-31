import UIKit
import SwiftUI

/// Hosts `PlayerAccessoryView` inside the tab bar's bottom accessory and
/// bridges the iOS 26 `tabAccessoryEnvironment` trait into the SwiftUI tree.
/// SwiftUI's `\.tabViewBottomAccessoryPlacement` environment is populated only
/// by a SwiftUI `TabView`, so with the UIKit shell the regular/inline switch
/// must be forwarded by hand.
final class PlayerAccessoryHostingController: UIHostingController<PlayerAccessoryView> {
  init(player: any SoundPlaying, imageLoader: any ImageLoading, onExpand: @escaping () -> Void) {
    super.init(
      rootView: PlayerAccessoryView(player: player, imageLoader: imageLoader, onExpand: onExpand)
    )
    view.backgroundColor = .clear
    sizingOptions = .intrinsicContentSize

    // The system applies the accessory-environment trait to the accessory's
    // *view* hierarchy (this VC's parent-derived traits don't carry it), so
    // register on the view. Reassigning `rootView` keeps view identity, so
    // SwiftUI state survives the swap.
    view.registerForTraitChanges([UITraitTabAccessoryEnvironment.self]) {
      [weak self] (view: UIView, _) in
      self?.rootView.isInline = view.traitCollection.tabAccessoryEnvironment == .inline
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
