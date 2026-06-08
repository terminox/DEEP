import SwiftUI

/// A sticky, stretchy video header for the top of Deep Sound. The sky footage
/// plays full-bleed under the status bar; pulling down grows the scene from the
/// top edge while it stays pinned, and its bottom feathers to transparent so it
/// dissolves into the atmosphere behind the scroll rather than ending on a hard
/// line. Purely atmospheric — content rides up over it (see `DeepSoundHomeView`).
///
/// Mirrors `MindGardenHomeView`'s hero, swapping the static image for video.
struct StretchyVideoHero: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var height: CGFloat = 320

  var body: some View {
    GeometryReader { geo in
      let stretch = max(0, geo.frame(in: .scrollView(axis: .vertical)).minY)
      LoopingVideoView(resource: "sky", isAnimating: !reduceMotion)
        .frame(width: geo.size.width, height: height + stretch)
        .clipped()
        .mask(heroFadeMask)
        .offset(y: -stretch)
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
