import SwiftUI

/// "Browse by intention" — a two-column grid of gradient category tiles.
struct IntentionGrid: View {
  let intentions: [SoundIntention]

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Browse by intention")
        .font(DeepType.sectionTitle)
        .foregroundStyle(DeepColor.deepPlum)
        .padding(.horizontal, DeepSpacing.edge)

      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(intentions) { intention in
          IntentionCell(intention: intention)
        }
      }
      .padding(.horizontal, DeepSpacing.edge)
    }
  }
}

private struct IntentionCell: View {
  let intention: SoundIntention

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      SoundArtwork(palette: intention.palette, cornerRadius: 18)
      Text(intention.title)
        .font(.system(.title3, design: .serif, weight: .light))
        .foregroundStyle(DeepColor.deepPlum)
        .padding(14)
    }
    .frame(height: 92)
  }
}
