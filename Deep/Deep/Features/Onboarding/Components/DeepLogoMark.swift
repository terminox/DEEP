import SwiftUI

/// The Deep mark — a thin ring with a single dot resting at its centre, the
/// same shape the app icon carries. Drawn rather than shipped as a raster so it
/// can hold the palette and glow on its own terms: a crisp ring seated inside
/// its own bloom, cream light over the welcome screen's sunrise.
///
/// Proportions are measured off the app icon — stroke 2% of the outer diameter,
/// dot 13% — and derived from `size`, so the mark can never drift from it.
struct DeepLogoMark: View {
  /// The mark's outer diameter. Everything else is a proportion of it.
  var size: CGFloat = 110
  /// The mark's own colour. Cream reads as light over the sunrise; a caller
  /// swaps in a solid tint when the backdrop has flattened to the same cream
  /// and a cream mark would vanish into it.
  var tint: Color = .moonCream
  /// Whether the mark carries its halo. Off when the backdrop has gone solid
  /// and the mark needs an edge rather than a bloom.
  var isGlowing: Bool = true

  private var strokeWidth: CGFloat { size * 0.02 }
  private var dotDiameter: CGFloat { size * 0.13 }

  var body: some View {
    ZStack {
      // The bloom: the same ring and dot blurred beneath the crisp pass, so the
      // mark reads as light rather than a pale line. A shadow alone can't carry
      // it — cream has almost no contrast left to cast over a cream veil.
      if isGlowing {
        ring
          .blur(radius: strokeWidth * 0.9)
          .opacity(0.6)

        dot
          .blur(radius: dotDiameter * 0.45)
          .opacity(0.6)
      }

      ring
      dot
    }
    .frame(width: size, height: size)
    // A tight bright halo inside a wide soft one. Stacked shadows compose, so
    // the second blooms the first's output — the falloff the logo artwork has.
    .shadow(color: isGlowing ? tint.opacity(0.9) : .clear, radius: size * 0.05)
    .shadow(color: isGlowing ? tint.opacity(0.5) : .clear, radius: size * 0.16)
    .accessibilityHidden(true)
  }

  /// `strokeBorder` insets the stroke, so the frame is the mark's outer
  /// diameter — the measurement the app-icon proportions are taken against.
  private var ring: some View {
    Circle()
      .strokeBorder(tint, lineWidth: strokeWidth)
  }

  private var dot: some View {
    Circle()
      .fill(tint)
      .frame(width: dotDiameter, height: dotDiameter)
  }
}

#Preview("Deep mark — cream over sunrise") {
  ZStack {
    AtmosphereBackground()

    VStack(spacing: .rhythm) {
      DeepLogoMark()
      DeepLogoMark(size: 64)
    }
    .padding(.horizontal, .edge)
  }
}

#Preview("Deep mark — flat backdrop, no halo") {
  ZStack {
    Color.moonCream
      .ignoresSafeArea()

    DeepLogoMark(tint: .irisDusk, isGlowing: false)
  }
}
