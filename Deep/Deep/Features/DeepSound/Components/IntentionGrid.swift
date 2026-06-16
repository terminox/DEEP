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
        .foregroundStyle(.deepPlum)
        .padding(.horizontal, .edge)

      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(intentions) { intention in
          IntentionCell(intention: intention)
        }
      }
      .padding(.horizontal, .edge)
    }
  }
}

private struct IntentionCell: View {
  let intention: SoundIntention

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      SoundArtwork(palette: intention.palette, imageURL: intention.imageURL, cornerRadius: 18)
        .overlay(
          // Scrim so the title stays legible over a photograph, not just the
          // light gradient it used to sit on.
          LinearGradient(
            colors: [.clear, Color.deepPlum.opacity(0.5)],
            startPoint: .center,
            endPoint: .bottom
          )
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
      Text(intention.title)
        .font(.system(.title3, design: .serif, weight: .light))
        .foregroundStyle(.white)
        .shadow(color: Color.deepPlum.opacity(0.35), radius: 6, y: 1)
        .padding(14)
    }
    .frame(height: 92)
  }
}
