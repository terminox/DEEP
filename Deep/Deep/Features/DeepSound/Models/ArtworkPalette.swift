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

  /// Gradient stops, top-leading → bottom-trailing.
  var colors: [Color] {
    switch self {
    case .tide:   return [DeepColor.skyWash, DeepColor.softLilac]
    case .dusk:   return [DeepColor.lavenderMist, DeepColor.blushPowder]
    case .bloom:  return [DeepColor.blushPowder, DeepColor.softLilac]
    case .ember:  return [DeepColor.peachCloud, DeepColor.blushPowder]
    case .mist:   return [DeepColor.softLilac, DeepColor.skyWash]
    case .aurora: return [DeepColor.skyWash, DeepColor.lavenderMist, DeepColor.blushPowder]
    }
  }
}
