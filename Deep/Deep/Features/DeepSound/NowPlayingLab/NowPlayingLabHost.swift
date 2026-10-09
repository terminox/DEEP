#if DEBUG
import SwiftUI
import UIKit
import DialKit

/// THROWAWAY. Knobs reach a variant through the environment rather than its
/// initialiser, so a slider drag only invalidates the leaves that read a knob.
extension EnvironmentValues {
  @Entry var nowPlayingLabKnobs = NowPlayingLabKnobs()
}

/// THROWAWAY. Registers the DialKit panel and renders exactly one player
/// variant. Mounted by `MainTabController.presentNowPlaying()` in Dev builds in
/// place of `NowPlayingView`.
///
/// `DialRoot` lives *here*, not in `DeepApp` like the mood lab's: the player is
/// a full-screen modal view controller that covers the window root, so a root
/// mount would sit underneath it.
struct NowPlayingLabHost: View {
  var onDismiss: () -> Void
  /// Tells the hosting controller which status bar the variant wants.
  var onLightStatusBar: (Bool) -> Void = { _ in }

  /// App-lifetime, never per view. A `@StateObject` panel dies with its
  /// hosting view, and the player's zoom transition tears hosting views down
  /// mid-graph-update: the panel's deinit then unregisters from DialKit's
  /// global store inside SwiftUI's teardown, and Swift's exclusivity check
  /// aborts the app. One panel for the process also keeps the chosen variant
  /// across opening and closing the player.
  @MainActor static let panel = DialPanelState(
    name: "Player",
    initial: NowPlayingLabHost.launchKnobs,
    controls: NowPlayingLabKnobs.controls
  )

  @ObservedObject private var dial = NowPlayingLabHost.panel

  /// Where the panel starts, optionally from the environment so a screenshot
  /// run can open straight into one variant:
  ///
  ///     SIMCTL_CHILD_NOW_PLAYING_VARIANT=postcard \
  ///     SIMCTL_CHILD_NOW_PLAYING_ARTWORK=forest xcrun simctl launch <udid> <bundle-id>
  static var launchKnobs: NowPlayingLabKnobs {
    var knobs = NowPlayingLabKnobs()
    let env = ProcessInfo.processInfo.environment
    if let id = env["NOW_PLAYING_VARIANT"], NowPlayingLabCatalog.all.contains(where: { $0.id == id }) {
      knobs.variant = id
    }
    if let art = env["NOW_PLAYING_ARTWORK"], NowPlayingLabArtwork(rawValue: art) != nil {
      knobs.artwork = art
    }
    return knobs
  }

  private var knobs: NowPlayingLabKnobs { dial.values }

  var body: some View {
    let variant = NowPlayingLabCatalog.variant(id: knobs.variant)
    ZStack {
      variant.make(onDismiss)
        .id(variant.id)
        .transition(.opacity)
    }
    .animation(.hush, value: knobs.variant)
    .environment(\.nowPlayingLabKnobs, knobs)
    .overlay {
      DialRoot(
        position: .topRight,
        defaultOpen: false,
        mode: .drawer,
        storageID: "deep.nowplaying.variants"
      )
      // iOS 26 has handed SwiftUI hosted under custom-presented UIKit an
      // `isEnabled` of false before — buttons dead while drags still work.
      .environment(\.isEnabled, true)
    }
    .onAppear { onLightStatusBar(variant.lightStatusBar) }
    .onChange(of: knobs.variant) { _, id in
      onLightStatusBar(NowPlayingLabCatalog.variant(id: id).lightStatusBar)
    }
  }
}

/// THROWAWAY. A hosting controller whose status bar a variant can flip, so
/// the clock reads over a dark photograph.
final class NowPlayingLabHostingController: UIHostingController<AnyView> {
  var lightStatusBar = false {
    didSet { setNeedsStatusBarAppearanceUpdate() }
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    lightStatusBar ? .lightContent : .darkContent
  }
}

/// THROWAWAY. The lab without the app around it, for launching straight in on
/// the simulator. Uses the app's simulated `SoundPlayer` so progress ticks.
struct NowPlayingLabStandalone: View {
  @State private var player: SoundPlayer = {
    let player = SoundPlayer()
    player.play(SoundLibrary.sleep[0])
    return player
  }()

  /// Real network loader. Downsampled to 2800px rather than the app's 1280:
  /// a full-bleed photo on a 3x phone is ~1200×2600px, and 1280 goes soft.
  @State private var imageLoader = ImageLoader(environmentKey: "now-playing-lab", maxPixelSize: 2800)

  var body: some View {
    NowPlayingLabHost(onDismiss: {})
      .environment(\.soundPlayer, player)
      .environment(\.imageLoader, imageLoader)
      .preferredColorScheme(.light)
  }
}

#Preview("Player lab") {
  NowPlayingLabHost {}
    .environment(\.soundPlayer, MockSoundPlayer.playing)
}
#endif
