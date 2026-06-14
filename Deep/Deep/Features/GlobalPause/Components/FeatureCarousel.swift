import SwiftUI

/// A titled, horizontally scrolling shelf of `FeatureCard`s — the home's
/// "Popular now" / "Today's sessions" sections.
struct FeatureCarousel: View {
  let title: String
  let items: [HomeItem]
  var seeAll: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: title, seeAll: seeAll)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(items) { item in
            FeatureCard(item: item)
          }
        }
        .padding(.horizontal, .edge)
      }
      .scrollClipDisabled()
      .scrollBounceBehavior(.basedOnSize)
    }
  }
}

#Preview("Feature Carousel") {
  ScrollView {
    FeatureCarousel(title: "Popular now", items: HomeLibrary.popular, seeAll: {})
      .padding(.vertical, 24)
  }
  .background { AtmosphereBackground() }
}
