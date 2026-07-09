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
    }
  }
}
