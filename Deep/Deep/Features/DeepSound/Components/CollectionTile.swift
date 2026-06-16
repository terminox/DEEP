import SwiftUI

/// A single artwork tile used inside the home carousels. Tapping asks the
/// coordinator to push the collection detail onto its `NavigationPath`.
struct CollectionTile: View {
  @Environment(\.openCollection) private var openCollection
  let collection: SoundCollection
  var size: CGFloat = 150

  var body: some View {
    Button {
      openCollection(collection)
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        SoundArtwork(palette: collection.palette, imageURL: collection.imageURL)
          .frame(width: size, height: size)
          .shadow(color: Color.lavenderMist.opacity(0.2), radius: 12, x: 0, y: 8)

        VStack(alignment: .leading, spacing: 2) {
          Text(collection.title)
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(.deepPlum)
            .lineLimit(1)
          Text(collection.subtitle)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .lineLimit(1)
        }
        .frame(width: size, alignment: .leading)
      }
    }
    .buttonStyle(.softPress)
  }
}
