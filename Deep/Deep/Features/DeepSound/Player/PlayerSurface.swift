import SwiftUI

/// The shared player chrome any screen can wear: a floating mini-player docked at
/// the bottom while something is playing, plus the Apple-Music-style Now Playing
/// it expands into. It reads the player from the environment, so every surface
/// that wears it shares one player and behaves identically.
///
/// The expand is the genuine iOS 26 system zoom: the mini bar is marked as the
/// transition *source* and the `fullScreenCover` carries
/// `navigationTransition(.zoom)`, so the bar physically morphs into the full
/// player and pulls back on dismiss (with interactive swipe-to-dismiss for free).
struct PlayerSurface: ViewModifier {
  @Environment(\.soundPlayer) private var player
  @State private var showNowPlaying = false
  @Namespace private var playerZoom

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .bottom) {
        if player.hasTrack {
          MiniPlayerBar { showNowPlaying = true }
            // The whole bar is the zoom source; it must stay mounted while the
            // cover is up so the morph has an anchor to expand from and pull back
            // into — hence no `&& !showNowPlaying` guard here.
            .matchedTransitionSource(id: SoundPlayerNamespace.player, in: playerZoom)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            // Fade only — for the bar appearing/disappearing as playback
            // starts/stops. The expand itself is owned by the zoom transition.
            .transition(.opacity)
        }
      }
      // A full-screen cover covers the UIKit tab bar on its own, so no tab-bar
      // dimming is needed; the zoom animates it up from the mini bar.
      .fullScreenCover(isPresented: $showNowPlaying) {
        NowPlayingView { showNowPlaying = false }
          .navigationTransition(.zoom(sourceID: SoundPlayerNamespace.player, in: playerZoom))
      }
  }
}

extension View {
  /// Wears the shared mini-player + zoom Now Playing surface, driven by the
  /// `\.soundPlayer` in the environment.
  func playerSurface() -> some View {
    modifier(PlayerSurface())
  }
}

#if DEBUG
#Preview("Player Surface — Playing") {
  Color.softLilac
    .ignoresSafeArea()
    .playerSurface()
    .environment(\.soundPlayer, MockSoundPlayer.playing)
}

#Preview("Player Surface — Idle") {
  Color.softLilac
    .ignoresSafeArea()
    .playerSurface()
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}
#endif
