import SwiftUI

/// Entry point for the standalone Deep Sound feature.
///
/// A `NavigationStack` over the home + detail screens, with the mini-player
/// docked at the bottom and Now Playing presented as an overlay so the artwork
/// can morph between the two via `matchedGeometryEffect`.
struct DeepSoundView: View {
  @State private var player = SoundPlayer()
  @State private var showNowPlaying = false
  @Namespace private var artworkNamespace

  private let miniPlayerInset: CGFloat = 92

  var body: some View {
    ZStack(alignment: .bottom) {
      AtmosphereBackground()

      NavigationStack {
        DeepSoundHomeView(bottomInset: bottomInset)
          .navigationDestination(for: SoundCollection.self) { collection in
            CollectionDetailView(collection: collection, bottomInset: bottomInset)
          }
      }

      if player.hasTrack && !showNowPlaying {
        MiniPlayerBar(artworkNamespace: artworkNamespace) {
          withAnimation(DeepMotion.exhale) { showNowPlaying = true }
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
          withAnimation(DeepMotion.exhale) { showNowPlaying = false }
        }
        .transition(.move(edge: .bottom))
        .zIndex(2)
      }
    }
    .environment(player)
    .preferredColorScheme(.light)
  }

  /// Reserve space for the mini-player only while something is playing.
  private var bottomInset: CGFloat {
    player.hasTrack ? miniPlayerInset : DeepSpacing.rhythm
  }
}

#Preview("Deep Sound — Home") {
  DeepSoundView()
}

#Preview("Deep Sound — Now Playing") {
  NowPlayingPreview()
}

/// Drives the player into a playing state so the Now Playing screen can be
/// previewed directly.
private struct NowPlayingPreview: View {
  @State private var player: SoundPlayer = {
    let p = SoundPlayer()
    p.play(SoundLibrary.featured)
    return p
  }()
  @Namespace private var ns

  var body: some View {
    NowPlayingView(artworkNamespace: ns) {}
      .environment(player)
  }
}
