import SwiftUI

/// A cause's visual stand-in until real imagery exists: the gradient `SoundArtwork`
/// with its SF Symbol motif floating in soft white on top. Reused at every size —
/// list thumbs, project cards, the cause hero — so a cause reads consistently
/// wherever it appears.
struct CompassionMotif: View {
  let symbol: String
  let palette: ArtworkPalette
  var cornerRadius: CGFloat = .tile
  /// Symbol size as a fraction of the smaller edge.
  var symbolScale: CGFloat = 0.42

  var body: some View {
    GeometryReader { geo in
      let edge = min(geo.size.width, geo.size.height)
      SoundArtwork(palette: palette, cornerRadius: cornerRadius)
        .overlay {
          Image(systemName: symbol)
            .font(.system(size: edge * symbolScale, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .shadow(color: Color.deepPlum.opacity(0.18), radius: 8, y: 3)
        }
    }
    .accessibilityHidden(true)
  }
}

#Preview("Compassion motifs") {
  HStack(spacing: 16) {
    CompassionMotif(symbol: "bird.fill", palette: .aurora)
    CompassionMotif(symbol: "cross.fill", palette: .bloom)
    CompassionMotif(symbol: "leaf.fill", palette: .mist)
  }
  .frame(height: 80)
  .padding()
  .background(.moonCream)
}
