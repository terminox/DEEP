import SwiftUI

/// A titled vertical list of collections — the destination for a section's
/// "See all" and for an Explore-category tap on the Global Pause home. Rows
/// push the real collection detail via `openCollection`.
struct CollectionListView: View {
  @Environment(\.openCollection) private var openCollection
  let title: String
  let collections: [SoundCollection]

  var body: some View {
    ScrollView(showsIndicators: false) {
      LazyVStack(spacing: 14) {
        ForEach(collections) { collection in
          row(for: collection)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.vertical, .rhythm)
    }
    .scrollBounceBehavior(.basedOnSize)
    .background { AtmosphereBackground() }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
  }

  private func row(for collection: SoundCollection) -> some View {
    Button {
      openCollection(collection)
    } label: {
      HStack(spacing: 14) {
        SoundArtwork(palette: collection.palette, imageURL: collection.imageURL, cornerRadius: 16)
          .frame(width: 72, height: 72)

        VStack(alignment: .leading, spacing: 3) {
          Text(collection.title)
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(.deepPlum)
            .lineLimit(1)
          Text(collection.subtitle)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .lineLimit(1)
          Text("\(collection.trackCount) tracks · \(collection.totalDuration.minutesString)")
            .font(DeepType.micro)
            .foregroundStyle(.driftGrey)
        }

        Spacer(minLength: 8)

        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.driftGrey)
      }
      .padding(12)
      .frostedCard()
    }
    .buttonStyle(.softPress)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(collection.title), \(collection.trackCount) tracks")
  }
}

#Preview("Collection List") {
  NavigationStack {
    CollectionListView(title: "Calm", collections: SoundLibrary.calm)
  }
  .environment(\.openCollection, { _ in })
}
