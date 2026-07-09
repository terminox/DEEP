import SwiftUI

/// Coordinator view for the Deep Sound flow — the business-specific composition
/// root. It owns navigation (home → collection detail, home → session intro)
/// and the player overlay (mini-player ↔ Now Playing), and nothing else.
///
/// Per the project's SwiftUI rules, a coordinator keeps styling to a minimum:
/// screen-level styling such as `AtmosphereBackground` lives in the leaf screens
/// (`DeepSoundHomeView`, `CollectionDetailView`) so it actually renders behind
/// their content. Placing the atmosphere here would hide it behind the
/// `NavigationStack`.
struct DeepSoundCoordinatorView: View {
  @State private var player: any SoundPlaying
  @State private var path = NavigationPath()

  private let miniPlayerInset: CGFloat = 92

  init(player: any SoundPlaying = SoundPlayer()) {
    _player = State(initialValue: player)
  }

  var body: some View {
    NavigationStack(path: $path) {
      DeepSoundHomeView(bottomInset: bottomInset)
        .navigationDestination(for: SoundCollection.self) { collection in
          CollectionDetailView(collection: collection, bottomInset: bottomInset)
        }
        .navigationDestination(for: DeepSession.self) { session in
          DeepSessionIntroView(session: session)
        }
    }
    .environment(\.openCollection, { collection in path.append(collection) })
    .environment(\.openSessionIntro, { session in path.append(session) })
    // The shared mini-player + Apple-Music zoom Now Playing. A full-screen cover
    // covers the tab bar on its own, so the bar no longer needs to be dimmed.
    // `.playerSurface()` sits *inside* the player injection so its own
    // `@Environment(\.soundPlayer)` resolves to this same `player`.
    .playerSurface()
    .environment(\.soundPlayer, player)
    .preferredColorScheme(.light)
  }

  /// Reserve space for the mini-player only while something is playing.
  private var bottomInset: CGFloat {
    player.hasTrack ? miniPlayerInset : .rhythm
  }
}

extension EnvironmentValues {
  /// Pushes a collection's detail onto the Deep Sound navigation path. The
  /// coordinator injects the real append; leaf tiles call it from a `Button`
  /// instead of hosting a `NavigationLink`, so all routing flows through the
  /// coordinator's single `NavigationPath`. The default is a no-op fallback that
  /// keeps previews hermetic.
  @Entry var openCollection: (SoundCollection) -> Void = { _ in }

  /// Pushes a session's intro onto the Deep Sound navigation path. Same
  /// mechanics as `openCollection`: the coordinator injects the real append,
  /// the Breathe hero card calls it from a `Button`, and the no-op default
  /// keeps previews hermetic.
  @Entry var openSessionIntro: (DeepSession) -> Void = { _ in }
}

#Preview("Deep Sound — Home") {
  DeepSoundCoordinatorView(player: MockSoundPlayer.idle)
}

#Preview("Deep Sound — Now Playing") {
  DeepSoundCoordinatorView(player: MockSoundPlayer.playing)
}
