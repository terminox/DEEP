import SwiftUI

/// A sticky, stretchy video header for the top of Deep Sound. The sky footage
/// plays full-bleed under the status bar; pulling down grows the scene from the
/// top edge while it stays pinned, and its bottom feathers to transparent so it
/// dissolves into the atmosphere behind the scroll rather than ending on a hard
/// line. Scrolling up drifts the scene away at a slower rate than the content
/// (parallax), so it sinks behind the page with depth. Purely atmospheric —
/// content rides up over it (see `DeepSoundHomeView`).
///
/// Mirrors `MindGardenHomeView`'s hero, swapping the static image for video.
struct StretchyVideoHero: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var height: CGFloat = 320

  /// How much slower the hero drifts than the scroll on the way up. 0 = moves
  /// with the content (no parallax); 1 = stays pinned. ~0.4 reads as gentle depth.
  private let parallaxDepth: CGFloat = 0.4

  /// Distance scrolled up over which the hero fully dissolves into the
  /// atmosphere. Shorter than `height` so it has melted away before it would
  /// otherwise leave the screen.
  private let fadeDistance: CGFloat = 220

  var body: some View {
    GeometryReader { geo in
      let minY = geo.frame(in: .scrollView(axis: .vertical)).minY
      // Pulling down (minY > 0) stretches the scene from the top edge.
      let stretch = max(0, minY)
      // Scrolling up (minY < 0) holds the hero back by a fraction of the
      // distance travelled, so it lags behind the content rising over it.
      let scrolledUp = -min(0, minY)
      let parallax = scrolledUp * parallaxDepth
      // ...and as it lags, it melts into the atmosphere behind it.
      let fade = min(1, scrolledUp / fadeDistance)
      LoopingVideoView(resource: "sky", isAnimating: !reduceMotion)
        .frame(width: geo.size.width, height: height + stretch)
        .clipped()
        .mask(heroFadeMask)
        .offset(y: -stretch + parallax)
        .opacity(1 - fade)
    }
    .frame(height: height)
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

#Preview("Stretchy Video Hero") {
  ScrollView {
    StretchyVideoHero()
    Color.clear.frame(height: 600)
  }
  .ignoresSafeArea(edges: .top)
  .background { AtmosphereBackground() }
}
