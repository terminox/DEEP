import SwiftUI

/// The Global Pause tab's content home — a stretchy video hero with a content
/// feed riding up over it (greeting, promo banner, carousels, mood check-in,
/// recommendations, explore). Modeled on the Calm iOS Home reference, themed in
/// the Deep design system. Leaf screens route via the `openHomeItem` action the
/// coordinator injects; this view hosts no navigation container itself.
struct GlobalPauseHomeView: View {
  var bottomInset: CGFloat = .rhythm

  private let heroHeight: CGFloat = 320
  private let heroOverlap: CGFloat = 80

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyVideoHero(resource: "sky", height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          GlobalPauseHeroSlot()

          DeepSessionEntryCard(session: DeepSessionLibrary.balancingBreath)
            .padding(.horizontal, .edge)

          FeatureCarousel(title: "Popular now", items: HomeLibrary.popular, seeAll: {})

          FeatureCarousel(title: "Today's sessions", items: HomeLibrary.todaysSessions, seeAll: {})

          RecommendationsSection(items: HomeLibrary.recommended)

          ExploreByContentSection()

          Color.clear.frame(height: bottomInset)
        }
        .padding(.top, -heroOverlap)
      }
    }
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.always)
    .ignoresSafeArea(edges: .top)
    .background { AtmosphereBackground() }
    .collapsibleHomeHeader(
      title: "Global Pause",
      subtitle: "Take a breath with the world today"
    )
  }
}

#Preview("Global Pause Home") {
  GlobalPauseHomeView(bottomInset: 100)
}
