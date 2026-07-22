import SwiftUI

/// A titled, horizontally scrolling shelf of `FeatureCard`s — the home's
/// "Popular now" / "Today's sessions" sections.
struct FeatureCarousel: View {
  let title: String
  let collections: [SoundCollection]
  var seeAll: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: title, seeAll: seeAll)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(collections) { collection in
            FeatureCard(collection: collection)
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
    FeatureCarousel(title: "Popular now", collections: SoundLibrary.calm, seeAll: {})
      .padding(.vertical, 24)
  }
  .background { AtmosphereBackground() }
  .environment(\.openCollection, { _ in })
  .environment(\.soundPlayer, MockSoundPlayer.idle)
}
