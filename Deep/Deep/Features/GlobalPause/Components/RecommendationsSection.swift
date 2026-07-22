import SwiftUI

/// The home's "Made for you" section — a horizontal carousel of square artwork
/// tiles. Mirrors DeepSound's `CollectionCarousel` (header over a row of square
/// `CollectionTile`s) so the two homes present their personalised shelves the
/// same way. Each tile routes through the coordinator on tap.
struct RecommendationsSection: View {
  let title: String
  let collections: [SoundCollection]
  var tileSize: CGFloat = 150

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: title)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(collections) { collection in
            HomeTile(collection: collection, size: tileSize)
          }
        }
        .padding(.horizontal, .edge)
      }
    }
  }
}

#Preview("Recommendations") {
  ScrollView {
    RecommendationsSection(title: "Made for you", collections: SoundLibrary.sleep)
      .padding(.vertical, 24)
  }
  .background { AtmosphereBackground() }
  .environment(\.openCollection, { _ in })
  .environment(\.soundPlayer, MockSoundPlayer.idle)
}
