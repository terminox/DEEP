import SwiftUI

/// A sticky, stretchy hero header. The media — looping bundled footage or an
/// asset-catalog still — draws full-bleed under the status bar; pulling down
/// grows the scene from the top edge while it stays pinned, and its bottom
/// feathers to transparent so it dissolves into the atmosphere behind the
/// scroll rather than ending on a hard line. Scrolling up drifts the scene away
/// at a slower rate than the content (parallax), so it sinks behind the page
/// with depth. Purely atmospheric — content rides up over it (see
/// `DeepSoundHomeView`, `MindGardenHomeView`, `GlobalPauseLobbyView`).
struct StretchyHero: View {
  /// What plays in the hero slot.
  enum Media {
    /// Bundled looping video (name without extension), muted, Reduce-Motion aware.
    case video(resource: String)
    /// Asset-catalog still, filled edge to edge.
    case image(name: String)
    /// Server-hosted looping video: the poster paints first, footage
    /// cross-fades in when ready and is cached for the next launch. A nil
    /// `url` shows the poster alone; a nil poster falls back to a gradient.
    case remoteVideo(url: URL?, posterURL: URL?)
  }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var media: Media
  var height: CGFloat = 320

  /// How much slower the hero drifts than the scroll on the way up. 0 = moves
  /// with the content (no parallax); 1 = stays pinned. ~0.4 reads as gentle depth.
  private let parallaxDepth: CGFloat = 0.4

  /// Distance scrolled up over which the hero fully dissolves into the
  /// atmosphere. Shorter than `height` so it has melted away before it would
  /// otherwise leave the screen.
  private let fadeDistance: CGFloat = 220

  /// Overscroll the hero absorbs 1:1 before the stretch starts damping, so a
  /// casual bounce looks exactly like an uncapped hero.
  private let freeStretch: CGFloat = 48

  /// Asymptotic ceiling on the stretch. Past `freeStretch` the growth eases
  /// toward this, so a deep pull can't balloon the media — the scene stays
  /// pinned to the top edge and the content simply travels a little ahead of
  /// its feathered bottom.
  private let maxStretch: CGFloat = 96

  var body: some View {
    GeometryReader { geo in
      let minY = geo.frame(in: .scrollView(axis: .vertical)).minY
      // Pulling down (minY > 0) stretches the scene from the top edge —
      // freely at first, then damped so a deep pull can't balloon the hero.
      let pull = max(0, minY)
      let stretch = pull <= freeStretch
        ? pull
        : freeStretch + (maxStretch - freeStretch)
            * (1 - exp(-(pull - freeStretch) / (maxStretch - freeStretch)))
      // Scrolling up (minY < 0) holds the hero back by a fraction of the
      // distance travelled, so it lags behind the content rising over it.
      let scrolledUp = -min(0, minY)
      let parallax = scrolledUp * parallaxDepth
      // ...and as it lags, it melts into the atmosphere behind it.
      let fade = min(1, scrolledUp / fadeDistance)
      mediaView
        .frame(width: geo.size.width, height: height + stretch)
        .clipped()
        .mask(heroFadeMask)
        // `-pull` cancels the frame's own ride down 1:1, so the media's top
        // edge never leaves the screen's top edge no matter how deep the
        // pull; the damped stretch only governs how far the scene grows.
        .offset(y: -pull + parallax)
        .opacity(1 - fade)
    }
    .frame(height: height)
  }

  @ViewBuilder
  private var mediaView: some View {
    switch media {
    case .video(let resource):
      LoopingVideoView(resource: resource, isAnimating: !reduceMotion)
    case .image(let name):
      Image(name)
        .resizable()
        .scaledToFill()
    case .remoteVideo(let url, let posterURL):
      RemoteLoopingVideoView(url: url, posterURL: posterURL, isAnimating: !reduceMotion)
    }
  }

  private var heroFadeMask: LinearGradient {
    LinearGradient(
      stops: [
        .init(color: .black, location: 0),
        .init(color: .black, location: 0.78),
        .init(color: .black.opacity(0), location: 1.0)
      ],
      startPoint: .top, endPoint: .bottom
    )
  }
}

#Preview("Stretchy video hero") {
  ScrollView {
    StretchyHero(media: .video(resource: "sky"))
    Color.clear.frame(height: 600)
  }
  .ignoresSafeArea(edges: .top)
  .background { AtmosphereBackground() }
}

#Preview("Stretchy remote-video hero") {
  ScrollView {
    StretchyHero(
      media: .remoteVideo(
        url: Bundle.main.url(forResource: "deep_oak_mature", withExtension: "mp4"),
        posterURL: nil
      )
    )
    Color.clear.frame(height: 600)
  }
  .ignoresSafeArea(edges: .top)
  .background { AtmosphereBackground() }
  .environment(\.imageLoader, FixtureImageLoader())
}

#Preview("Stretchy image hero") {
  ScrollView {
    StretchyHero(media: .image(name: "DJFukuHero"))
    Color.clear.frame(height: 600)
  }
  .ignoresSafeArea(edges: .top)
  .background { AtmosphereBackground() }
}
