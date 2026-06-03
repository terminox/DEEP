import SwiftUI

/// A single artwork tile used inside the home carousels. Tapping navigates to
/// the collection detail via the enclosing `NavigationStack`.
struct CollectionTile: View {
  let collection: SoundCollection
  var size: CGFloat = 150

  var body: some View {
    NavigationLink(value: collection) {
      VStack(alignment: .leading, spacing: 8) {
        SoundArtwork(palette: collection.palette)
          .frame(width: size, height: size)
          .shadow(color: DeepColor.lavenderMist.opacity(0.2), radius: 12, x: 0, y: 8)

        VStack(alignment: .leading, spacing: 2) {
          Text(collection.title)
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(DeepColor.deepPlum)
            .lineLimit(1)
          Text(collection.subtitle)
            .font(DeepType.caption)
            .foregroundStyle(DeepColor.driftGrey)
            .lineLimit(1)
        }
        .frame(width: size, alignment: .leading)
      }
    }
    .buttonStyle(.softPress)
  }
}
