import SwiftUI

/// The home's "Explore" section — a two-column grid of artwork tiles, one per
/// backend category: the category's lead-collection photograph under its
/// palette wash with the category name laid over a legibility scrim. Tapping a
/// tile pushes the category's collection list via `openCollectionList`.
struct ExploreByContentSection: View {
  let categories: [PauseCategory]

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "Explore")

      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(categories) { category in
          ExploreTile(category: category)
        }
      }
      .padding(.horizontal, .edge)
    }
  }
}

private struct ExploreTile: View {
  @Environment(\.openCollectionList) private var openCollectionList
  let category: PauseCategory

  var body: some View {
    Button {
      openCollectionList(category.title, category.collections)
    } label: {
      ZStack(alignment: .bottomLeading) {
        SoundArtwork(
          palette: category.artwork?.palette ?? .mist,
          imageURL: category.artwork?.imageURL,
          cornerRadius: 18
        )
        .overlay(
          // Scrim so the title stays legible over a photograph.
          LinearGradient(
            colors: [.clear, Color.deepPlum.opacity(0.5)],
            startPoint: .center,
            endPoint: .bottom
          )
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        Text(category.title)
          .font(.system(.title3, design: .serif, weight: .light))
          .foregroundStyle(.white)
          .shadow(color: Color.deepPlum.opacity(0.35), radius: 6, y: 1)
          .padding(14)
      }
      .frame(height: 92)
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("Explore \(category.title)")
  }
}

#Preview("Explore by Content") {
  ScrollView {
    ExploreByContentSection(categories: [
      PauseCategory(id: "calm", slug: "calm", title: "Calm", collections: SoundLibrary.calm),
      PauseCategory(id: "morning", slug: "morning", title: "Morning", collections: SoundLibrary.morning),
      PauseCategory(id: "sleep", slug: "sleep", title: "Sleep", collections: SoundLibrary.sleep),
      PauseCategory(id: "deep-kids", slug: "deep-kids", title: "Deep Kids", collections: SoundLibrary.deepKids),
    ])
    .padding(.vertical, 24)
  }
  .background { AtmosphereBackground() }
  .environment(\.openCollectionList, { _, _ in })
}
