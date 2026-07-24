import SwiftUI

/// The SwiftUI root hosted inside the tab bar's bottom accessory
/// (`UITabAccessory` in `MainTabController`). It swaps between the full mini
/// player and its inline variant as the tab bar minimizes, and asks the shell
/// to expand into Now Playing.
///
/// Expansion is deliberately *not* presented from this tree: a
/// `fullScreenCover` presented from inside the accessory renders above
/// everything but receives no touches (the accessory's system container is
/// hit-tested only within the pill), so the shell presents Now Playing from
/// the tab controller with a UIKit zoom transition sourced from this view —
/// the same morph, owned one level up.
struct PlayerAccessoryView: View {
  /// Injected explicitly (not read from the environment): the accessory tree
  /// hangs off the UIKit shell, outside any tab's SwiftUI environment.
  let player: any SoundPlaying
  /// Asks the shell (`MainTabController`) to present the full Now Playing.
  var onExpand: () -> Void
  /// Driven by `PlayerAccessoryHostingController` from the iOS 26
  /// `tabAccessoryEnvironment` trait — `true` while the tab bar is minimized
  /// and the accessory rides inline beside it.
  var isInline: Bool = false

  var body: some View {
    Group {
      if isInline {
        MiniPlayerInlineBar(onExpand: onExpand)
      } else {
        MiniPlayerBar(onExpand: onExpand)
      }
    }
    .environment(\.soundPlayer, player)
  }
}

#if DEBUG
// The shipped view rides on the system accessory's glass; previews stand that
// chrome in with a plain `glassEffect` capsule so the content reads in context.
#Preview("Accessory — Regular") {
  PlayerAccessoryView(player: MockSoundPlayer.playing, onExpand: {})
    .glassEffect(.regular, in: Capsule())
    .padding(.horizontal, .edge)
    .frame(maxHeight: .infinity)
    .background { AtmosphereBackground() }
}

#Preview("Accessory — Inline") {
  PlayerAccessoryView(player: MockSoundPlayer.playing, onExpand: {}, isInline: true)
    .glassEffect(.regular, in: Capsule())
    .frame(width: 240)
    .frame(maxHeight: .infinity)
    .background { AtmosphereBackground() }
}
#endif
