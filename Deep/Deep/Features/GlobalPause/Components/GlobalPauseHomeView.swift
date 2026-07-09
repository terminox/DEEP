import SwiftUI

/// The Global Pause tab's content home — a stretchy video hero with a content
/// feed riding up over it (greeting, the Global Pause card, carousels,
/// recommendations, explore). Modeled on the Calm iOS Home reference, themed in
/// the Deep design system. Leaf screens route via the `openHomeItem` /
/// `openGlobalPause` actions the coordinator injects; this view hosts no
/// navigation container itself.
///
/// The Global Pause card is the coordinator-owned UIKit `GlobalPauseCardView`,
/// seated here through `GlobalPauseCardSlot` — the card-lift transition
/// re-parents that one instance between this feed and the lobby.
struct GlobalPauseHomeView: View {
  var card: GlobalPauseCardView

  private let heroHeight: CGFloat = 320
  private let heroOverlap: CGFloat = 80

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyVideoHero(resource: "sky", height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          GlobalPauseCardSlot(card: card)
            .frame(height: 200)
            .padding(.horizontal, .edge)

          DeepSessionEntryCard(session: DeepSessionLibrary.balancingBreath)
            .padding(.horizontal, .edge)

          FeatureCarousel(title: "Popular now", items: HomeLibrary.popular, seeAll: {})

          FeatureCarousel(title: "Today's sessions", items: HomeLibrary.todaysSessions, seeAll: {})

          RecommendationsSection(items: HomeLibrary.recommended)

          ExploreByContentSection()

          // The tab bar and mini player are real safe-area insets now; this is
          // just breathing room after the last section.
          Color.clear.frame(height: .rhythm)
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
  GlobalPauseHomeView(card: GlobalPauseCardView(scene: .preview))
}
