import SwiftUI

/// Artwork for a collection. Shows the collection's photograph beneath a soft
/// branded wash of its `palette` gradient; with no `imageURL` it falls back to
/// the pure gradient — the dimensional, orb-like quality DESIGN.md calls for.
/// A thin wrapper over the shared `ArtworkImage` so DeepSound and Global Pause
/// render media the same way.
struct SoundArtwork: View {
  let palette: ArtworkPalette
  /// Optional photograph shown under the gradient wash.
  var imageURL: URL? = nil
  var cornerRadius: CGFloat = .tile
  /// See `ArtworkImage.bordered` — full-bleed artwork switches the rim off.
  var bordered: Bool = true

  var body: some View {
    ArtworkImage(
      url: imageURL,
      colors: palette.colors,
      cornerRadius: cornerRadius,
      bordered: bordered
    )
  }
}

#Preview {
  HStack(spacing: 16) {
    ForEach(ArtworkPalette.allCases, id: \.self) { palette in
      SoundArtwork(palette: palette)
        .frame(width: 80, height: 80)
    }
  }
  .padding()
  .background(.moonCream)
}
