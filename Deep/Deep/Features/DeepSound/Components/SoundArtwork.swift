import SwiftUI

/// Abstract gradient artwork for a collection. A soft radial sheen gives it
/// the dimensional, orb-like quality DESIGN.md calls for without any bitmap.
struct SoundArtwork: View {
  let palette: ArtworkPalette
  var cornerRadius: CGFloat = DeepRadius.tile

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    shape
      .fill(
        LinearGradient(
          colors: palette.colors,
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        RadialGradient(
          colors: [.white.opacity(0.38), .white.opacity(0.0)],
          center: .topLeading,
          startRadius: 2,
          endRadius: 220
        )
      )
      .overlay(
        RadialGradient(
          colors: [DeepColor.deepPlum.opacity(0.10), .clear],
          center: .bottomTrailing,
          startRadius: 2,
          endRadius: 220
        )
      )
      .clipShape(shape)
      .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
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
  .background(DeepColor.moonCream)
}
