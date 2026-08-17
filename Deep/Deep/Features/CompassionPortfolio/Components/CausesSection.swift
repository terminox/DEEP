import SwiftUI

/// The causes the community's hearts flow to, as a horizontal shelf. The
/// community-level reach figure now lives on `CommunityPoolCard` instead — if
/// it stayed here too, the identical sentence would appear twice within ~60pt
/// of scroll.
struct CausesSection: View {
  let categories: [CompassionCategory]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(
        title: "Where your hearts go",
        subtitle: "Send them to a cause and we give, for real, on your behalf."
      )

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(categories) { CategoryTile(category: $0) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, .edge)
        // Deliberately no `.scrollClipDisabled()`. `frostedCard`'s shadow is
        // `radius: 24, y: 12` — with clipping off it bleeds ~36pt into the
        // header and next section, and slides sideways as you scroll. This
        // vertical padding is what preserves the soft part of the plume
        // instead. Every shelf carrying `frostedCard` cards ships this way
        // (`FieldReportsSection`, `RecommendationsSection`,
        // `CollectionCarousel`); `FeatureCarousel` is the outlier, not the
        // pattern — don't "fix" this to match it.
        .padding(.vertical, 6)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
  }
}

#Preview("Causes section") {
  ScrollView {
    CausesSection(categories: CompassionLibrary.categories)
      .padding(.vertical)
  }
  .background { AtmosphereBackground() }
  .environment(\.openCategory, { _ in })
}
