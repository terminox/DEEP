import SwiftUI

/// A named gradient pairing drawn from the Deep palette. Until real cover
/// imagery exists, every collection renders abstract gradient artwork — in
/// keeping with DESIGN.md ("orbs, gradients, never photography of faces").
enum ArtworkPalette: String, CaseIterable, Hashable {
  case tide
  case dusk
  case bloom
  case ember
  case mist
  case aurora
  case dawn

  // MARK: Single-hue pairings
  //
  // One colour falling into a deeper shade of itself. The compassion causes wear
  // these: `CompassionRing` resolves an arc's gradient across the *whole* circle,
  // so a two-hue palette shows an arc only the slice of gradient beneath it — and
  // two causes sitting in the same band of the circle can render the same colour
  // (`.mist` and `.tide` are exact reverses of one another). A single-hue arc is
  // its cause's colour wherever on the ring it lands.
  case veil
  case petal
  case iris
  case shore
  case hearth

  /// Gradient stops, top-leading → bottom-trailing.
  var colors: [Color] {
    switch self {
    case .tide:   return [.skyWash, .softLilac]
    case .dusk:   return [.lavenderMist, .blushPowder]
    case .bloom:  return [.blushPowder, .softLilac]
    case .ember:  return [.peachCloud, .blushPowder]
    case .mist:   return [.softLilac, .skyWash]
    case .aurora: return [.skyWash, .lavenderMist, .blushPowder]
    case .dawn:   return [.moonCream, .peachCloud]
    case .veil:   return Self.deepening(.softLilac, to: 0.08)
    case .petal:  return Self.deepening(.blushPowder, to: 0.12)
    case .iris:   return Self.deepening(.lavenderMist, from: 0.22, to: 0.34)
    case .shore:  return Self.deepening(.skyWash, to: 0.12)
    case .hearth: return Self.deepening(.peachCloud, to: 0.12)
    }
  }

  /// A colour into a deeper shade of itself, seated on `deepPlum` — the colour
  /// that shadows and grounds everything else in the app, so the deep end stays
  /// inside the palette instead of introducing a hue of its own.
  ///
  /// `from` seats the *light* end deeper too. Only `iris` uses it, and it earns
  /// its keep: the palette holds four hues for five causes, so the violets have
  /// to share one. `softLilac` and `lavenderMist` are 3° apart and differ only in
  /// lightness — 8 points of it — so any generous ramp slides softLilac's deep end
  /// onto lavenderMist's light end and the two causes become the same colour.
  /// Keeping the ramps shallow and seating `iris` below where `veil` bottoms out
  /// gives the pair two lightness bands that cannot overlap: pale lilac, deep violet.
  private static func deepening(_ colour: Color, from: Double = 0, to: Double) -> [Color] {
    [colour.mix(with: .deepPlum, by: from), colour.mix(with: .deepPlum, by: to)]
  }
}
