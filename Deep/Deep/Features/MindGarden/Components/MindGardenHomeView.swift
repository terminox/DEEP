import SwiftUI

/// The Mind Garden home — a personal calm space. One quiet scroll: an
/// atmospheric dawn header, a greeting with today's progress and streak, a nudge
/// into today's practice, and the garden growing alongside the journey.
///
/// This is the leaf screen, so it owns its screen-level styling: the hero scene
/// bleeds under the status bar and `AtmosphereBackground` sits behind the scroll
/// (per the project's coordinator rules, styling lives here, not in the
/// coordinator, so it actually renders).
struct MindGardenHomeView: View {
  var state: GardenState = .sample
  /// Extra bottom space so content clears the tab bar / any docked chrome.
  var bottomInset: CGFloat = .rhythm

  private let heroHeight: CGFloat = 320
  /// How far the greeting card rides up over the hero.
  private let heroOverlap: CGFloat = 52
  private let heroImageName = "MindGardenHero"
  private let scrollSpace = "gardenScroll"

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        stretchyHero

        VStack(alignment: .leading, spacing: .rhythm) {
          GardenGreetingCard(state: state)
            .padding(.horizontal, .edge)

          DailyPracticeCard(minutesRemaining: state.minutesRemaining)
            .padding(.horizontal, .edge)

          GrowYourGardenSection(stages: state.stages)

          Color.clear.frame(height: bottomInset)
        }
        .padding(.top, -heroOverlap)
      }
    }
    .coordinateSpace(name: scrollSpace)
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.always)
    .ignoresSafeArea(edges: .top)
    .background { AtmosphereBackground() }
  }

  /// A sticky, stretchy header: pulling down grows the scene from the top edge
  /// while it stays pinned; its bottom feathers to transparent so it dissolves
  /// into the atmosphere behind the scroll rather than ending on a hard line.
  private var stretchyHero: some View {
    GeometryReader { geo in
      let stretch = max(0, geo.frame(in: .named(scrollSpace)).minY)
      Image(heroImageName)
        .resizable()
        .scaledToFill()
        .frame(width: geo.size.width, height: heroHeight + stretch)
        .clipped()
        .mask(heroFadeMask)
        .offset(y: -stretch)
    }
    .frame(height: heroHeight)
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

#Preview("Mind Garden — Home") {
  MindGardenHomeView(state: .sample)
}

#Preview("Mind Garden — Fresh start") {
  MindGardenHomeView(state: .fresh)
}
