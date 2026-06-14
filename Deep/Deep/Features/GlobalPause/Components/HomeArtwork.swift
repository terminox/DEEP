import SwiftUI

/// Abstract gradient artwork for a home item. A soft radial sheen at the top-left
/// and a plum shadow at the bottom-right give it an orb-like dimension without any
/// bitmap — the home's theme-token-driven twin of `SoundArtwork`.
struct HomeArtwork: View {
  let palette: HomePalette
  var cornerRadius: CGFloat = .tile

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
          colors: [.white.opacity(0.38), .white.opacity(0)],
          center: .topLeading,
          startRadius: 2,
          endRadius: 240
        )
      )
      .overlay(
        RadialGradient(
          colors: [Color.deepPlum.opacity(0.12), .clear],
          center: .bottomTrailing,
          startRadius: 2,
          endRadius: 240
        )
      )
      .clipShape(shape)
      .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
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
