import SwiftUI

/// The session's centrepiece — a luminous orb inside a fixed halo ring, after
/// the Calm breathing reference. Purely visual: the parent decides `swell`
/// (0…1) and owns the animation that carries it between phases, so the orb
/// renders any moment of the breath without its own clock.
struct BreathingOrb: View {
  /// How full the breath is: 0 rests well inside the ring, 1 meets it.
  var swell: CGFloat

  var body: some View {
    ZStack {
      // The halo the breath swells towards, with a single bead resting on it.
      Circle()
        .strokeBorder(.white.opacity(0.65), lineWidth: 1.5)
        .overlay(alignment: .top) {
          Circle()
            .fill(.white)
            .frame(width: 10, height: 10)
            .offset(y: -4)
        }

      orb
        .padding(14)
        .scaleEffect(0.55 + 0.45 * swell)
    }
    .aspectRatio(1, contentMode: .fit)
  }

  private var orb: some View {
    Circle()
      .fill(
        RadialGradient(
          colors: [
            .white.opacity(0.95),
            .softLilac.opacity(0.75),
            .lavenderMist.opacity(0.45),
            .skyWash.opacity(0.25),
          ],
          center: UnitPoint(x: 0.5, y: 0.42),
          startRadius: 8,
          endRadius: 150
        )
      )
      .shadow(color: .lavenderMist.opacity(0.5), radius: 40, x: 0, y: 0)
  }
}

#Preview("Breathing orb — rest and full") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      BreathingOrb(swell: 0)
        .frame(width: 220)
      BreathingOrb(swell: 1)
        .frame(width: 220)
    }
  }
}
