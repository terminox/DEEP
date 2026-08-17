import SwiftUI

/// A cause's visual stand-in until real imagery exists: the gradient `SoundArtwork`
/// with its SF Symbol motif floating in soft white on top. Reused at every size —
/// list thumbs, project cards, the cause hero — so a cause reads consistently
/// wherever it appears.
///
/// At tile sizes the symbol sits crisp and centred. At hero scale that reads as a
/// missing-image placeholder, so the symbol can instead be pushed large, faint and
/// soft to the trailing edge, cropped by the frame — an editorial watermark rather
/// than an icon.
struct CompassionMotif: View {
  let symbol: String
  let palette: ArtworkPalette
  var cornerRadius: CGFloat = .tile
  /// Symbol size as a fraction of the smaller edge.
  var symbolScale: CGFloat = 0.42
  var symbolOpacity: Double = 0.92
  /// Softens the symbol into the gradient. Kept at 0 for crisp tile motifs.
  var symbolBlur: CGFloat = 0
  /// The plum drop shadow that seats the symbol on the gradient. Its radius is
  /// fixed, so at chip sizes (a 20pt legend marker) it smears across the whole
  /// motif instead of grounding the glyph — switch it off there.
  var symbolShadow: Bool = true
  var symbolAlignment: Alignment = .center
  /// See `ArtworkImage.bordered` — full-bleed artwork switches the rim off.
  var bordered: Bool = true

  var body: some View {
    GeometryReader { geo in
      let edge = min(geo.size.width, geo.size.height)
      SoundArtwork(palette: palette, cornerRadius: cornerRadius, bordered: bordered)
        .overlay(alignment: symbolAlignment) {
          Image(systemName: symbol)
            .font(.system(size: edge * symbolScale, weight: .semibold))
            .foregroundStyle(.white.opacity(symbolOpacity))
            .blur(radius: symbolBlur)
            .shadow(color: Color.deepPlum.opacity(symbolShadow ? 0.18 : 0), radius: 8, y: 3)
        }
        // The watermark deliberately overruns its frame; the clip keeps the
        // overflow inside the artwork instead of bleeding over neighbours.
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    .accessibilityHidden(true)
  }
}

#Preview("Compassion motifs") {
  VStack(spacing: 16) {
    HStack(spacing: 16) {
      CompassionMotif(symbol: "bird.fill", palette: .aurora)
      CompassionMotif(symbol: "cross.fill", palette: .bloom)
      CompassionMotif(symbol: "leaf.fill", palette: .mist)
    }
    .frame(height: 80)

    // The hero watermark treatment.
    CompassionMotif(
      symbol: "leaf.fill",
      palette: .mist,
      cornerRadius: 0,
      symbolScale: 1.5,
      symbolOpacity: 0.20,
      symbolBlur: 3,
      symbolAlignment: .trailing,
      bordered: false
    )
    .frame(height: 180)
  }
  .padding()
  .background(.moonCream)
}
