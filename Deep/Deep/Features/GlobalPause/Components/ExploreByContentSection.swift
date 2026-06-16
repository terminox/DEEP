import SwiftUI

/// The home's "Explore" section — a two-column grid of artwork tiles, one per
/// `HomeCategory`. Mirrors DeepSound's `IntentionGrid` so browsing reads the same
/// across the two homes: a photograph under the palette wash with the category
/// name laid over a legibility scrim.
struct ExploreByContentSection: View {
  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "Explore")

      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(HomeCategory.allCases) { category in
          ExploreTile(category: category)
        }
      }
      .padding(.horizontal, .edge)
    }
  }
}

private struct ExploreTile: View {
  let category: HomeCategory

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      HomeArtwork(palette: category.palette, imageURL: category.imageURL, cornerRadius: 18)
        .overlay(
          // Scrim so the title stays legible over a photograph.
          LinearGradient(
            colors: [.clear, Color.deepPlum.opacity(0.5)],
            startPoint: .center,
            endPoint: .bottom
          )
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
      Text(category.rawValue)
        .font(.system(.title3, design: .serif, weight: .light))
        .foregroundStyle(.white)
        .shadow(color: Color.deepPlum.opacity(0.35), radius: 6, y: 1)
        .padding(14)
    }
    .frame(height: 92)
  }
}

#Preview("Explore by Content") {
  ScrollView {
    ExploreByContentSection()
      .padding(.vertical, 24)
  }
  .background { AtmosphereBackground() }
}
