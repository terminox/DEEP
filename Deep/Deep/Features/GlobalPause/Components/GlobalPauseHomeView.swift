import SwiftUI

/// The Global Pause tab's content home — a stretchy video hero with a content
/// feed riding up over it (greeting, promo banner, carousels, mood check-in,
/// recommendations, explore). Modeled on the Calm iOS Home reference, themed in
/// the Deep design system. Leaf screens route via the `openHomeItem` action the
/// coordinator injects; this view hosts no navigation container itself.
struct GlobalPauseHomeView: View {
  var bottomInset: CGFloat = .rhythm
  /// Injectable so previews and tests can pin a deterministic greeting.
  var now: Date = .now

  private let heroHeight: CGFloat = 320
  private let heroOverlap: CGFloat = 80

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyVideoHero(resource: "sky", height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          greeting

          HomePromoBanner(banner: HomeLibrary.banner)

          FeatureCarousel(title: "Popular now", items: HomeLibrary.popular, seeAll: {})

          FeatureCarousel(title: "Today's sessions", items: HomeLibrary.todaysSessions, seeAll: {})

          MoodCheckInCard()

          RecommendationsSection(items: HomeLibrary.recommended, seeAll: {})

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
    .safeAreaInset(edge: .top, spacing: 0) {
      HomeTopBar()
        .padding(.top, 8)
    }
  }

  private var greeting: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(timeGreeting)
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
      Text("Take a breath with the world today")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
    }
    .padding(.horizontal, .edge)
  }

  private var timeGreeting: String {
    switch Calendar.current.component(.hour, from: now) {
    case 5..<12:  return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<22: return "Good evening"
    default:      return "Good night"
    }
  }
}

#Preview("Global Pause Home") {
  GlobalPauseHomeView(bottomInset: 100)
}
