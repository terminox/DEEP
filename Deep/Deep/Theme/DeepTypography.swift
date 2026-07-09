import SwiftUI
import UIKit

// MARK: - Type tokens (single source of truth)

/// One type style, declared once and materialised into the framework-native
/// types — a SwiftUI `Font` and a UIKit `UIFont` — so the same token reads
/// identically across both layers and can never drift between them.
/// All sizes are anchored to a Dynamic Type text style so they scale.
private struct DeepTypeToken {
  let style: Font.TextStyle
  let uiStyle: UIFont.TextStyle
  let design: Font.Design
  let uiDesign: UIFontDescriptor.SystemDesign
  let weight: Font.Weight
  let uiWeight: UIFont.Weight
  var italic: Bool = false

  var font: Font {
    let base = Font.system(style, design: design, weight: weight)
    return italic ? base.italic() : base
  }

  var uiFont: UIFont {
    var descriptor = UIFont.preferredFont(forTextStyle: uiStyle).fontDescriptor
    if let designed = descriptor.withDesign(uiDesign) {
      descriptor = designed
    }
    if italic,
       let italicised = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) {
      descriptor = italicised
    }
    descriptor = descriptor.addingAttributes(
      [.traits: [UIFontDescriptor.TraitKey.weight: uiWeight]]
    )
    // Size 0 keeps the text style's Dynamic Type size.
    return UIFont(descriptor: descriptor, size: 0)
  }
}

/// The Deep type scale, aligned with DESIGN.md. Every style the app uses
/// originates here; `DeepType` (SwiftUI) and the `UIFont` accessors below are
/// thin projections of these entries — never declare a font inline elsewhere.
private enum DeepTypePalette {
  /// Serif italic wordmark — "deep", "Global Pause". H2-ish.
  static let wordmark = DeepTypeToken(
    style: .title, uiStyle: .title1,
    design: .serif, uiDesign: .serif,
    weight: .light, uiWeight: .light,
    italic: true
  )
  /// H2 serif light — card titles, affirmations.
  static let displayTitle = DeepTypeToken(
    style: .title2, uiStyle: .title2,
    design: .serif, uiDesign: .serif,
    weight: .light, uiWeight: .light
  )
  /// H3 sans medium — UI section headers.
  static let sectionTitle = DeepTypeToken(
    style: .headline, uiStyle: .headline,
    design: .default, uiDesign: .default,
    weight: .medium, uiWeight: .medium
  )
  /// Body copy.
  static let body = DeepTypeToken(
    style: .subheadline, uiStyle: .subheadline,
    design: .default, uiDesign: .default,
    weight: .regular, uiWeight: .regular
  )
  /// Body copy at medium weight — pill labels, emphasised rows.
  static let bodyMedium = DeepTypeToken(
    style: .subheadline, uiStyle: .subheadline,
    design: .default, uiDesign: .default,
    weight: .medium, uiWeight: .medium
  )
  /// Caption — metadata, schedule lines.
  static let caption = DeepTypeToken(
    style: .footnote, uiStyle: .footnote,
    design: .default, uiDesign: .default,
    weight: .regular, uiWeight: .regular
  )
  /// Micro label — small caps, e.g. HR / MIN / SEC.
  static let micro = DeepTypeToken(
    style: .caption2, uiStyle: .caption2,
    design: .default, uiDesign: .default,
    weight: .medium, uiWeight: .medium
  )
  /// Rounded mono digits — countdown, large counts.
  static let counter = DeepTypeToken(
    style: .title2, uiStyle: .title2,
    design: .rounded, uiDesign: .rounded,
    weight: .medium, uiWeight: .medium
  )
  /// Rounded mono digits at countdown scale.
  static let countdown = DeepTypeToken(
    style: .title3, uiStyle: .title3,
    design: .rounded, uiDesign: .rounded,
    weight: .medium, uiWeight: .medium
  )
  /// Big participant count.
  static let bigNumber = DeepTypeToken(
    style: .title, uiStyle: .title1,
    design: .rounded, uiDesign: .rounded,
    weight: .medium, uiWeight: .medium
  )
  /// Serif italic reveal — the tapped-country name over the globe.
  static let revealTitle = DeepTypeToken(
    style: .title3, uiStyle: .title3,
    design: .serif, uiDesign: .serif,
    weight: .light, uiWeight: .light,
    italic: true
  )
}

// MARK: - SwiftUI fonts

/// Centralized type styles for SwiftUI, e.g. `.font(DeepType.displayTitle)`.
enum DeepType {
  static let wordmark: Font = DeepTypePalette.wordmark.font
  static let displayTitle: Font = DeepTypePalette.displayTitle.font
  static let sectionTitle: Font = DeepTypePalette.sectionTitle.font
  static let body: Font = DeepTypePalette.body.font
  static let caption: Font = DeepTypePalette.caption.font
  static let micro: Font = DeepTypePalette.micro.font
  static let counter: Font = DeepTypePalette.counter.font
  static let countdown: Font = DeepTypePalette.countdown.font
  static let bigNumber: Font = DeepTypePalette.bigNumber.font
  static let revealTitle: Font = DeepTypePalette.revealTitle.font
}

// MARK: - UIKit fonts

/// The same tokens for UIKit, e.g. `label.font = .displayTitle`. Only the
/// styles UIKit code actually consumes are surfaced; add projections here as
/// UIKit call sites appear.
extension UIFont {
  static var displayTitle: UIFont { DeepTypePalette.displayTitle.uiFont }
  static var caption: UIFont { DeepTypePalette.caption.uiFont }
  static var bodyMedium: UIFont { DeepTypePalette.bodyMedium.uiFont }
  static var revealTitle: UIFont { DeepTypePalette.revealTitle.uiFont }
}
