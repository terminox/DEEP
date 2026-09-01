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
  /// Whether this token needs a Thai companion face.
  ///
  /// Only the serif tokens do. New York carries no Thai glyphs, so in Thai it
  /// silently falls back to a system sans and the whole serif register — the
  /// wordmark, card titles, affirmations, the country reveal — flattens into
  /// the same voice as the UI chrome. The rounded tokens carry digits only, so
  /// SF Pro Rounded's lack of Thai coverage never shows.
  var serif: Bool = false
  /// Fixed-width digits, for text that ticks (countdowns) — a proportional
  /// "1" is narrower than a "4", so a live timer would jitter sideways.
  var monospacedDigits: Bool = false
  /// An explicit point size, for the one style the scale can't reach: a numeral
  /// a whole screen is about stands far above `.largeTitle`. It is still
  /// anchored — `UIFontMetrics` scales it against `uiStyle` — so Dynamic Type
  /// moves it like every other token here.
  var fixedSize: CGFloat? = nil

  var font: Font {
    // A sized token has no text-style twin to project from, so it comes back
    // through the UIKit metrics that scale it. A Thai serif token comes back
    // the same way, because the bundled face is only reachable through a
    // UIKit descriptor.
    if fixedSize != nil || wantsThaiSerif { return Font(uiFont as CTFont) }
    var base = Font.system(style, design: design, weight: weight)
    if monospacedDigits { base = base.monospacedDigit() }
    return italic ? base.italic() : base
  }

  /// True when this token is a serif one *and* the app is currently reading in
  /// Thai — the only case where the system face has to be swapped out.
  private var wantsThaiSerif: Bool {
    serif && AppLanguage.current.usesThaiScript
  }

  var uiFont: UIFont {
    if wantsThaiSerif { return thaiSerifFont }
    var descriptor = fixedSize
      .map { UIFont.systemFont(ofSize: $0, weight: uiWeight).fontDescriptor }
      ?? UIFont.preferredFont(forTextStyle: uiStyle).fontDescriptor
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
    if monospacedDigits {
      descriptor = descriptor.addingAttributes([
        .featureSettings: [[
          UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
          UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector
        ]]
      ])
    }
    // Size 0 keeps the text style's Dynamic Type size.
    let font = UIFont(descriptor: descriptor, size: fixedSize ?? 0)
    // An explicit size doesn't grow on its own; the style's metrics move it.
    guard fixedSize != nil else { return font }
    return UIFontMetrics(forTextStyle: uiStyle).scaledFont(for: font)
  }

  /// The bundled Noto Serif Thai, cut to this token's weight.
  ///
  /// One variable face covers the whole scale: the `wght` axis is driven
  /// directly rather than shipping a static file per weight. Italic is
  /// deliberately dropped — Thai has no italic tradition, and a synthesised
  /// slant on stacked vowel and tone marks reads as a rendering fault rather
  /// than emphasis.
  private var thaiSerifFont: UIFont {
    let size = fixedSize ?? UIFont.preferredFont(forTextStyle: uiStyle).pointSize
    let descriptor = UIFontDescriptor(fontAttributes: [
      .family: DeepThaiSerif.family,
      kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [
        DeepThaiSerif.weightAxis: DeepThaiSerif.axisValue(for: uiWeight)
      ]
    ])
    let font = UIFont(descriptor: descriptor, size: size)
    // Thai needs more room above and below the baseline than Latin: vowels
    // stack above and tone marks above those, with a second class below. The
    // metrics scaling keeps Dynamic Type honest for the explicit sizes.
    guard fixedSize != nil else { return font }
    return UIFontMetrics(forTextStyle: uiStyle).scaledFont(for: font)
  }
}

// MARK: - Thai serif companion

/// The bundled Thai serif and the one axis Deep drives on it.
private enum DeepThaiSerif {
  static let family = "Noto Serif Thai"
  /// The OpenType `wght` axis, as CoreText's four-character identifier.
  static let weightAxis = 0x77676874

  /// Maps the type scale's UIKit weight onto the variable font's 100–900 axis.
  static func axisValue(for weight: UIFont.Weight) -> Int {
    switch weight {
    case .ultraLight: 200
    case .thin: 250
    case .light: 300
    case .medium: 500
    case .semibold: 600
    case .bold: 700
    case .heavy: 800
    case .black: 900
    default: 400
    }
  }
}

extension AppLanguage {
  /// Whether copy in this language is written in Thai script — the question
  /// typography actually needs answered, as opposed to which language it is.
  var usesThaiScript: Bool {
    switch self {
    case .thai: true
    case .english: false
    // Following the device: Thai only when the bundle actually resolved Thai.
    case .system: Bundle.main.preferredLocalizations.first == "th"
    }
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
    italic: true,
    serif: true
  )
  /// H2 serif light — card titles, affirmations.
  static let displayTitle = DeepTypeToken(
    style: .title2, uiStyle: .title2,
    design: .serif, uiDesign: .serif,
    weight: .light, uiWeight: .light,
    serif: true
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
  /// Pill-label copy with ticking digits ("Live in 13:44") — bodyMedium's
  /// scale and weight, mono digits so the tick never jitters sideways.
  static let countdown = DeepTypeToken(
    style: .subheadline, uiStyle: .subheadline,
    design: .default, uiDesign: .default,
    weight: .medium, uiWeight: .medium,
    monospacedDigits: true
  )
  /// Big participant count.
  static let bigNumber = DeepTypeToken(
    style: .title, uiStyle: .title1,
    design: .rounded, uiDesign: .rounded,
    weight: .medium, uiWeight: .medium
  )
  /// The one numeral a whole screen is about — the Deep Session length being
  /// chosen. The scale's largest rung; mono digits so the roll between values
  /// never shifts the numeral sideways.
  static let heroNumber = DeepTypeToken(
    style: .largeTitle, uiStyle: .largeTitle,
    design: .rounded, uiDesign: .rounded,
    weight: .light, uiWeight: .light,
    monospacedDigits: true,
    fixedSize: 96
  )
  /// Serif italic reveal — the tapped-country name over the globe.
  static let revealTitle = DeepTypeToken(
    style: .title3, uiStyle: .title3,
    design: .serif, uiDesign: .serif,
    weight: .light, uiWeight: .light,
    italic: true,
    serif: true
  )
}

// MARK: - SwiftUI fonts

/// Centralized type styles for SwiftUI, e.g. `.font(DeepType.displayTitle)`.
enum DeepType {
  static var wordmark: Font { DeepTypePalette.wordmark.font }
  static var displayTitle: Font { DeepTypePalette.displayTitle.font }
  static var sectionTitle: Font { DeepTypePalette.sectionTitle.font }
  static var body: Font { DeepTypePalette.body.font }
  static var caption: Font { DeepTypePalette.caption.font }
  static var micro: Font { DeepTypePalette.micro.font }
  static var counter: Font { DeepTypePalette.counter.font }
  static var countdown: Font { DeepTypePalette.countdown.font }
  static var bigNumber: Font { DeepTypePalette.bigNumber.font }
  static var heroNumber: Font { DeepTypePalette.heroNumber.font }
  static var revealTitle: Font { DeepTypePalette.revealTitle.font }
}

// MARK: - UIKit fonts

/// The same tokens for UIKit, e.g. `label.font = .displayTitle`. Only the
/// styles UIKit code actually consumes are surfaced; add projections here as
/// UIKit call sites appear.
extension UIFont {
  static var displayTitle: UIFont { DeepTypePalette.displayTitle.uiFont }
  static var caption: UIFont { DeepTypePalette.caption.uiFont }
  static var bodyMedium: UIFont { DeepTypePalette.bodyMedium.uiFont }
  static var micro: UIFont { DeepTypePalette.micro.uiFont }
  static var countdown: UIFont { DeepTypePalette.countdown.uiFont }
  static var revealTitle: UIFont { DeepTypePalette.revealTitle.uiFont }
}

// MARK: - Tracking

/// Letterspacing companions to the type scale, e.g. `.tracking(.microTracking)`.
extension CGFloat {
  /// Breathing room for all-caps `DeepType.micro` eyebrow labels.
  static let microTracking: CGFloat = 1.4
}
