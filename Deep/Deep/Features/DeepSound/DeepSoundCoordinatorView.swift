import SwiftUI

/// Coordinator view for the Deep Sound flow — the business-specific composition
/// root. It owns navigation (home → collection detail), and nothing else. The
/// mini player lives in the tab bar's bottom accessory, owned by the app shell
/// (`MainTabController`), not by this tab.
///
/// Per the project's SwiftUI rules, a coordinator keeps styling to a minimum:
/// screen-level styling such as `AtmosphereBackground` lives in the leaf screens
/// (`DeepSoundHomeView`, `CollectionDetailView`) so it actually renders behind
/// their content. Placing the atmosphere here would hide it behind the
/// `NavigationStack`.
struct DeepSoundCoordinatorView: View {
  @State private var player: any SoundPlaying
  @State private var path = NavigationPath()

  init(player: any SoundPlaying = SoundPlayer()) {
    _player = State(initialValue: player)
  }

  var body: some View {
    NavigationStack(path: $path) {
      // The bottom accessory participates in the safe area, so content clears
      // the mini player natively; `.rhythm` is pure breathing room.
      DeepSoundHomeView(bottomInset: .rhythm)
        .navigationDestination(for: SoundCollection.self) { collection in
          CollectionDetailView(collection: collection, bottomInset: .rhythm)
        }
    }
    .environment(\.openCollection, { collection in path.append(collection) })
    // Leaf play buttons drive the same shared player that feeds the shell's
    // bottom-accessory mini player.
    .environment(\.soundPlayer, player)
    .preferredColorScheme(.light)
  }
}

extension EnvironmentValues {
  /// Pushes a collection's detail onto the Deep Sound navigation path. The
  /// coordinator injects the real append; leaf tiles call it from a `Button`
  /// instead of hosting a `NavigationLink`, so all routing flows through the
  /// coordinator's single `NavigationPath`. The default is a no-op fallback that
  /// keeps previews hermetic.
  @Entry var openCollection: (SoundCollection) -> Void = { _ in }
}

#Preview("Deep Sound — Home") {
  DeepSoundCoordinatorView(player: MockSoundPlayer.idle)
}

#Preview("Deep Sound — Now Playing") {
  DeepSoundCoordinatorView(player: MockSoundPlayer.playing)
}
