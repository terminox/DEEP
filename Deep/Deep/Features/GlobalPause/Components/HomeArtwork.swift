import SwiftUI

/// Artwork for a home item. Shows the item's photograph beneath a soft branded
/// wash of its `palette` gradient; with no `imageURL` it falls back to the pure
/// gradient — an orb-like dimension without any bitmap. The home's twin of
/// `SoundArtwork`; both are thin wrappers over the shared `ArtworkImage` so the
/// two features render media the same way.
struct HomeArtwork: View {
  let palette: HomePalette
  /// Optional photograph shown under the gradient wash.
  var imageURL: URL? = nil
  var cornerRadius: CGFloat = .tile

  var body: some View {
    ArtworkImage(url: imageURL, colors: palette.colors, cornerRadius: cornerRadius)
  }
}

#Preview("Home Artwork") {
  HStack(spacing: 16) {
    ForEach(HomePalette.allCases, id: \.self) { palette in
      HomeArtwork(palette: palette)
        .frame(width: 72, height: 72)
    }
  }
  .padding()
  .background(.moonCream)
}
