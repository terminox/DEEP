import SwiftUI

/// Coordinator view for the Deep Sound flow — the business-specific composition
/// root. It owns navigation (home → collection detail) and the player overlay
/// (mini-player ↔ Now Playing), and nothing else.
///
/// Per the project's SwiftUI rules, a coordinator keeps styling to a minimum:
/// screen-level styling such as `AtmosphereBackground` lives in the leaf screens
/// (`DeepSoundHomeView`, `CollectionDetailView`) so it actually renders behind
/// their content. Placing the atmosphere here would hide it behind the
/// `NavigationStack`.
struct DeepSoundCoordinatorView: View {
  /// Notifies the host (e.g. the UIKit tab bar) when Now Playing opens/closes.
  var onNowPlayingVisibilityChange: ((Bool) -> Void)? = nil

  @State private var player: any SoundPlaying
  @State private var showNowPlaying = false
  @Namespace private var artworkNamespace

  private let miniPlayerInset: CGFloat = 92

  init(
    player: any SoundPlaying = SoundPlayer(),
    onNowPlayingVisibilityChange: ((Bool) -> Void)? = nil
  ) {
    _player = State(initialValue: player)
    self.onNowPlayingVisibilityChange = onNowPlayingVisibilityChange
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      NavigationStack {
        DeepSoundHomeView(bottomInset: bottomInset)
          .navigationDestination(for: SoundCollection.self) { collection in
            CollectionDetailView(collection: collection, bottomInset: bottomInset)
          }
      }

      if player.hasTrack && !showNowPlaying {
        MiniPlayerBar(artworkNamespace: artworkNamespace) {
          withAnimation(.exhale) { showNowPlaying = true }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(1)
      }
    }
    .overlay {
      if showNowPlaying {
        NowPlayingView(artworkNamespace: artworkNamespace) {
          withAnimation(.exhale) { showNowPlaying = false }
        }
        .transition(.move(edge: .bottom))
        .zIndex(2)
      }
    }
    .environment(\.soundPlayer, player)
    .preferredColorScheme(.light)
    .onChange(of: showNowPlaying) { _, isOpen in
      onNowPlayingVisibilityChange?(isOpen)
    }
  }

  /// Reserve space for the mini-player only while something is playing.
  private var bottomInset: CGFloat {
    player.hasTrack ? miniPlayerInset : .rhythm
  }
}

#Preview("Deep Sound — Home") {
  DeepSoundCoordinatorView(player: MockSoundPlayer.idle)
}

#Preview("Deep Sound — Now Playing") {
  DeepSoundCoordinatorView(player: MockSoundPlayer.playing)
}
