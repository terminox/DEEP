import SwiftUI

/// A titled horizontal row of collection tiles, like Apple Music's home rows.
struct CollectionCarousel: View {
  let title: String
  let collections: [SoundCollection]
  var tileSize: CGFloat = 150

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(DeepType.sectionTitle)
        .foregroundStyle(DeepColor.deepPlum)
        .padding(.horizontal, DeepSpacing.edge)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(collections) { collection in
            CollectionTile(collection: collection, size: tileSize)
          }
        }
        .padding(.horizontal, DeepSpacing.edge)
      }
    }
  }
}
