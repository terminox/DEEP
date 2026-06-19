import SwiftUI

/// A **scale-invariant** atmosphere for the Global Pause cards: a `moonCream` base
/// with centered, size-relative blooms, so it reads identically whether it backs a
/// 340pt card or a full-screen takeover.
///
/// This exists because `AtmosphereBackground` pins its blurred orbs at fixed
/// full-screen offsets — inside a small, resizing card those orbs sit off-frame and
/// then "swim" in as the card grows, which is what made the hero-expansion card look
/// wrong. Sizing every bloom to the container's own `min(width, height)` keeps the
/// look constant across the whole expand → collapse animation.
struct CardAtmosphere: View {
  var body: some View {
    GeometryReader { geo in
      let side = min(geo.size.width, geo.size.height)
      ZStack {
        Color.moonCream

        RadialGradient(
          colors: [Color.softLilac.opacity(0.55), .clear],
          center: .center,
          startRadius: 0,
          endRadius: side * 0.85
        )

        RadialGradient(
          colors: [Color.blushPowder.opacity(0.32), .clear],
          center: UnitPoint(x: 0.5, y: 1.05),
          startRadius: 0,
          endRadius: side * 0.7
        )
      }
    }
  }
}

#Preview("CardAtmosphere — card vs full") {
  VStack(spacing: 24) {
    CardAtmosphere()
      .frame(height: 200)
      .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
    CardAtmosphere()
  }
  .padding()
}
