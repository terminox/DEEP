#if DEBUG
import SwiftUI

// PROTOTYPE, throwaway. Answers one question: what should giving hearts look
// like once it carries more hearts and a thank-you from the app? Six variants,
// switched from the floating bar on the Compassion home (or launched with
// `-heartThanksVariant <raw>`). Nothing here persists, and none of it ships:
// the winner gets rebuilt properly, then this folder is deleted.

enum HeartThanksVariant: String, CaseIterable, Identifiable {
  case current, inSheet, toCause, fullScreen, onCard, confetti

  var id: String { rawValue }

  var pill: String {
    switch self {
    case .current: "Now"
    case .inSheet: "A Sheet"
    case .toCause: "B Cause"
    case .fullScreen: "C Full"
    case .onCard: "D Card"
    case .confetti: "E Confetti"
    }
  }

  var title: String {
    switch self {
    case .current: "Current (baseline)"
    case .inSheet: "A · Thanks in the sheet"
    case .toCause: "B · Hearts fly to the cause"
    case .fullScreen: "C · Full-screen moment"
    case .onCard: "D · Thanks on the cause card"
    case .confetti: "E · Heart confetti"
    }
  }

  var blurb: String {
    switch self {
    case .current: "One heart floats up, sheet closes after 0.9s."
    case .inSheet: "Hearts rise through the sheet, it turns into a thank-you. Done closes."
    case .toCause: "Hearts arc into the cause icon, a halo, then the thanks. Closes itself."
    case .fullScreen: "Sheet closes, a calm full screen of rising hearts says thanks. Tap to close."
    case .onCard: "Sheet closes, hearts drift into the cause card, a note blooms on it."
    case .confetti: "A burst of heart confetti over the sheet, then the thanks. Breaks DESIGN.md."
    }
  }

  var breaksDesignRules: Bool { self == .confetti }
}

/// One gift, as the thank-you needs it.
struct HeartThanksMoment: Identifiable, Equatable {
  let id = UUID()
  let category: CompassionCategory
  let amount: Int

  var thanks: String { "Thank you for giving to \(category.name)" }
  var amountLine: String { amount == 1 ? "1 heart" : "\(amount.formatted()) hearts" }

  /// The particle budget: grows with the gift, capped so 100 hearts stays calm.
  /// 1 → 5, 10 → 18, 100+ → 24.
  var particles: Int {
    Swift.min(24, 5 + Int(4 * log2(Double(Swift.max(amount, 1)))))
  }
}

/// The places in the donate sheet a variant reaches for.
enum HeartThanksSpot: Hashable {
  case cta, motif, causeText, readout, content
}

@Observable
final class HeartThanksPrototype {
  var variant: HeartThanksVariant

  /// The gift playing inside the sheet (A, B, E).
  var sheetMoment: HeartThanksMoment?
  /// Sheet sections a variant has faded out to make room for its thanks.
  var hidden: Set<HeartThanksSpot> = []
  /// Bumps each time a heart lands on the sheet's cause motif (B).
  var motifBeat = 0

  /// C: handed over when the sheet closes, presented by the coordinator.
  var pendingCover: HeartThanksMoment?
  var coverMoment: HeartThanksMoment?

  /// D: the gift the home is flying into a tile, and the tile showing thanks.
  var cardMoment: HeartThanksMoment?
  var tileThanks: HeartThanksMoment?
  /// Per cause, so a beat only ever presses the tile it landed on.
  var tileBeats: [String: Int] = [:]

  init() {
    let raw = UserDefaults.standard.string(forKey: "heartThanksVariant") ?? ""
    variant = HeartThanksVariant(rawValue: raw) ?? .inSheet
  }

  /// The sheet opened: forget the last gift.
  func resetSheet() {
    sheetMoment = nil
    hidden = []
    motifBeat = 0
  }

  /// Called by `DonateHeartsView.donate()` after the ledger has the hearts.
  func give(_ amount: Int, to category: CompassionCategory) {
    let moment = HeartThanksMoment(category: category, amount: amount)
    switch variant {
    case .current: break
    case .inSheet, .toCause, .confetti: sheetMoment = moment
    case .fullScreen:
      pendingCover = moment
      sheetMoment = moment
    case .onCard:
      cardMoment = moment
      sheetMoment = moment
    }
  }

  /// The coordinator's sheet `onDismiss`.
  func sheetDidDismiss() {
    resetSheet()
    guard let pendingCover else { return }
    self.pendingCover = nil
    var quiet = Transaction()
    quiet.disablesAnimations = true
    withTransaction(quiet) { coverMoment = pendingCover }
  }
}

extension EnvironmentValues {
  @Entry var heartThanksPrototype: HeartThanksPrototype?
}

// MARK: - Anchors

struct HeartThanksSheetAnchors: PreferenceKey {
  static let defaultValue: [HeartThanksSpot: Anchor<CGRect>] = [:]
  static func reduce(value: inout [HeartThanksSpot: Anchor<CGRect>], nextValue: () -> [HeartThanksSpot: Anchor<CGRect>]) {
    value.merge(nextValue()) { $1 }
  }
}

struct HeartThanksTileAnchors: PreferenceKey {
  static let defaultValue: [String: Anchor<CGRect>] = [:]
  static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
    value.merge(nextValue()) { $1 }
  }
}

private struct PrototypeHidden: ViewModifier {
  @Environment(\.heartThanksPrototype) private var prototype
  let spot: HeartThanksSpot

  func body(content: Content) -> some View {
    let hidden = prototype?.hidden.contains(spot) == true
    // While a gift plays, the sheet underneath is finishing its sentence:
    // a second tap on the CTA would give twice.
    let playing = spot == .content && prototype?.sheetMoment != nil
    content
      .opacity(hidden ? 0 : 1)
      .scaleEffect(hidden ? 0.96 : 1)
      .animation(.bloom, value: hidden)
      .allowsHitTesting(!playing)
  }
}

/// A soft press each time `beat` bumps, the way a heart landing would feel.
private struct PrototypeBeat: ViewModifier {
  let beat: Int

  func body(content: Content) -> some View {
    content.keyframeAnimator(initialValue: 1.0, trigger: beat) { view, scale in
      view.scaleEffect(scale)
    } keyframes: { _ in
      CubicKeyframe(0.86, duration: 0.1)
      SpringKeyframe(1.0, duration: 0.5, spring: .init(response: 0.55, dampingRatio: 0.78))
    }
  }
}

private struct PrototypeMotifBeat: ViewModifier {
  @Environment(\.heartThanksPrototype) private var prototype
  func body(content: Content) -> some View {
    content.modifier(PrototypeBeat(beat: prototype?.motifBeat ?? 0))
  }
}

extension View {
  func prototypeAnchor(_ spot: HeartThanksSpot) -> some View {
    anchorPreference(key: HeartThanksSheetAnchors.self, value: .bounds) { [spot: $0] }
  }

  func prototypeHidden(_ spot: HeartThanksSpot) -> some View {
    modifier(PrototypeHidden(spot: spot))
  }

  func prototypeMotifBeat() -> some View {
    modifier(PrototypeMotifBeat())
  }

  func prototypeBeat(_ beat: Int) -> some View {
    modifier(PrototypeBeat(beat: beat))
  }
}

// MARK: - Halo

/// DESIGN.md's halo pulse: one slow ring outward, once.
struct HaloRingPrototype: View {
  var cornerRadius: CGFloat = .chip
  @State private var spread = false

  var body: some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .strokeBorder(Color.blushPowder, lineWidth: 2)
      .scaleEffect(spread ? 1.35 : 1)
      .opacity(spread ? 0 : 0.9)
      .allowsHitTesting(false)
      .onAppear {
        withAnimation(.ripple) { spread = true }
      }
  }
}
#endif
