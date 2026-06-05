import SwiftUI
import UIKit

// MARK: - Palette (single source of truth)

/// One palette entry, declared once as raw RGB and materialised into the
/// framework-native types — a SwiftUI `Color` and a UIKit `UIColor` — so the
/// same token reads identically across both layers.
private struct DeepColorToken {
  let red: Double
  let green: Double
  let blue: Double

  var color: Color { Color(red: red, green: green, blue: blue) }
  var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }
}

/// The Deep palette. Every colour the app uses originates here; the SwiftUI and
/// UIKit accessors below are thin projections of these values — never duplicate
/// an RGB literal elsewhere.
private enum DeepPalette {
  static let lavenderMist = DeepColorToken(red: 0.722, green: 0.655, blue: 0.910) // #B8A7E8
  static let softLilac    = DeepColorToken(red: 0.831, green: 0.773, blue: 0.941) // #D4C5F0
  static let blushPowder  = DeepColorToken(red: 0.957, green: 0.788, blue: 0.831) // #F4C9D4
  static let skyWash      = DeepColorToken(red: 0.773, green: 0.847, blue: 0.941) // #C5D8F0
  static let peachCloud   = DeepColorToken(red: 0.961, green: 0.851, blue: 0.769) // #F5D9C4
  static let moonCream    = DeepColorToken(red: 0.984, green: 0.969, blue: 1.000) // #FBF7FF
  static let deepPlum     = DeepColorToken(red: 0.239, green: 0.212, blue: 0.329) // #3D3654
  static let driftGrey    = DeepColorToken(red: 0.545, green: 0.510, blue: 0.659) // #8B82A8
}

// MARK: - SwiftUI colours

/// Leading-dot access wherever a `ShapeStyle`/`Color` is expected, e.g.
/// `.foregroundStyle(.lavenderMist)`, `.fill(.blushPowder)`, `.background(.moonCream)`.
/// Because the constraint is `Self == Color`, these are also reachable as plain
/// values — `Color.deepPlum`, `Color.lavenderMist.opacity(0.4)`.
extension ShapeStyle where Self == Color {
  static var lavenderMist: Color { DeepPalette.lavenderMist.color }
  static var softLilac: Color { DeepPalette.softLilac.color }
  static var blushPowder: Color { DeepPalette.blushPowder.color }
  static var skyWash: Color { DeepPalette.skyWash.color }
  static var peachCloud: Color { DeepPalette.peachCloud.color }
  static var moonCream: Color { DeepPalette.moonCream.color }
  static var deepPlum: Color { DeepPalette.deepPlum.color }
  static var driftGrey: Color { DeepPalette.driftGrey.color }
}

// MARK: - UIKit colours

/// The same tokens for UIKit, e.g. `tabBar.tintColor = .lavenderMist`.
extension UIColor {
  static var lavenderMist: UIColor { DeepPalette.lavenderMist.uiColor }
  static var softLilac: UIColor { DeepPalette.softLilac.uiColor }
  static var blushPowder: UIColor { DeepPalette.blushPowder.uiColor }
  static var skyWash: UIColor { DeepPalette.skyWash.uiColor }
  static var peachCloud: UIColor { DeepPalette.peachCloud.uiColor }
  static var moonCream: UIColor { DeepPalette.moonCream.uiColor }
  static var deepPlum: UIColor { DeepPalette.deepPlum.uiColor }
  static var driftGrey: UIColor { DeepPalette.driftGrey.uiColor }
}

// MARK: - Motion

/// Named SwiftUI animations, dot-accessible wherever an `Animation` is expected:
/// `.animation(.exhale, value:)`, `withAnimation(.settle) { … }`.
extension Animation {
  static let exhale = Animation.timingCurve(0.32, 0.0, 0.36, 1.0, duration: 0.8)
  static let bloom  = Animation.timingCurve(0.22, 0.61, 0.36, 1.0, duration: 0.7)
  static let settle = Animation.spring(response: 0.55, dampingFraction: 0.78)
}

// MARK: - Corner radii

/// Dot-accessible `CGFloat` radii — identical in SwiftUI and UIKit, e.g.
/// `RoundedRectangle(cornerRadius: .card)`.
extension CGFloat {
  static let card: CGFloat = 24  // primary cards / hero artwork
  static let chip: CGFloat = 999 // fully rounded chips & pills
  static let tile: CGFloat = 20  // tiles & small artwork
}

// MARK: - Spacing

/// Dot-accessible `CGFloat` spacing, e.g. `.padding(.horizontal, .edge)`,
/// `VStack(spacing: .rhythm)`.
extension CGFloat {
  static let edge: CGFloat = 20   // screen horizontal inset
  static let rhythm: CGFloat = 24 // vertical rhythm between sections
}
