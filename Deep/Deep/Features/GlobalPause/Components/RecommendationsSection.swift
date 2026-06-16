import SwiftUI

/// The home's "Made for you" section — a horizontal carousel of square artwork
/// tiles. Mirrors DeepSound's `CollectionCarousel` (header over a row of square
/// `CollectionTile`s) so the two homes present their personalised shelves the
/// same way. Each tile routes through the coordinator on tap.
struct RecommendationsSection: View {
  let items: [HomeItem]
  var tileSize: CGFloat = 150

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "Made for you")

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(items) { item in
            HomeTile(item: item, size: tileSize)
          }
        }
        .padding(.horizontal, .edge)
      }
    }
  }
}

#Preview("Recommendations") {
  ScrollView {
    RecommendationsSection(items: HomeLibrary.recommended)
      .padding(.vertical, 24)
  }
  .background { AtmosphereBackground() }
  .environment(\.openHomeItem, { _ in })
}
