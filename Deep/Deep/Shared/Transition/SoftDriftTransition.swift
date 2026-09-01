import SwiftUI

/// The app's calm screen hand-off: a soft crossfade with a small vertical
/// drift and a breath of blur that resolves into focus. Going forward the new
/// screen rises in from below while the old one drifts upward — one
/// continuous, unhurried surfacing; going back the motion mirrors. Pair with
/// `.hush` (`withAnimation(.hush)` or `.animation(.hush, value:)`) so every
/// screen-level dissolve shares one tempo.
///
/// Under Reduce Motion the drift and blur are dropped, leaving a plain
/// crossfade (same duration — less motion, not less time). Set `fades: false`
/// when an enclosing layer already crossfades (the onboarding content block),
/// so opacities never compound; with Reduce Motion that degrades to identity.
/// Set `veils: false` on subtrees that must never rasterize under an animated
/// blur — anything containing `AtmosphereBackground` (its internally blurred
/// orbs clip into hard-edged discs) or a hosted UIKit shell.
struct SoftDriftTransition: Transition {
  enum Direction {
    case forward, backward
  }

  var direction: Direction = .forward
  /// When false, opacity is left to an enclosing crossfade.
  var fades: Bool = true
  /// When false, the dissolve keeps its drift and fade but skips the blur.
  var veils: Bool = true

  func body(content: Content, phase: TransitionPhase) -> some View {
    content.modifier(
      SoftDriftEffect(phase: phase, direction: direction, fades: fades, veils: veils)
    )
  }
}

/// Dot-accessible per the motion-token conventions: `.transition(.softDrift)`,
/// `.transition(.softDrift(.backward))`, `.transition(.softDrift(veils: false))`.
extension Transition where Self == SoftDriftTransition {
  static var softDrift: SoftDriftTransition { SoftDriftTransition() }
  static func softDrift(_ direction: SoftDriftTransition.Direction) -> SoftDriftTransition {
    SoftDriftTransition(direction: direction)
  }
  static func softDrift(veils: Bool) -> SoftDriftTransition {
    SoftDriftTransition(veils: veils)
  }
}

/// The soft drift's single source of truth for its magnitudes. Shared with
/// `BreatheLoadingView`'s exhale, which draws the same motion by hand — the
/// two must never drift apart (pun intended).
enum SoftDrift {
  /// Vertical travel of the drift, in points.
  static let drop: CGFloat = 16
  /// Gaussian blur at the fully-veiled ends of the dissolve, in points.
  static let veil: CGFloat = 6
}

/// A `ViewModifier` so the effect can read the environment (a bare
/// `Transition` cannot host `@Environment`); centralises Reduce Motion
/// handling for every call site.
private struct SoftDriftEffect: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let phase: TransitionPhase
  let direction: SoftDriftTransition.Direction
  let fades: Bool
  let veils: Bool

  func body(content: Content) -> some View {
    content
      .opacity(fades && !phase.isIdentity ? 0 : 1)
      .offset(y: reduceMotion ? 0 : offset)
      .blur(radius: !veils || reduceMotion || phase.isIdentity ? 0 : SoftDrift.veil)
  }

  private var offset: CGFloat {
    switch phase {
    case .identity: 0
    case .willAppear: direction == .forward ? SoftDrift.drop : -SoftDrift.drop
    case .didDisappear: direction == .forward ? -SoftDrift.drop : SoftDrift.drop
    }
  }
}

#if DEBUG
#Preview("Soft drift") {
  @Previewable @State var showsFirst = true
  @Previewable @State var direction = SoftDriftTransition.Direction.forward

  ZStack {
    // Stand-ins for two screens — no real dependencies.
    if showsFirst {
      LinearGradient(colors: [.peachCloud, .blushPowder], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
        .overlay {
          Text("First screen")
            .font(DeepType.sectionTitle)
            .foregroundStyle(.deepPlum)
        }
        .transition(.softDrift(direction))
    } else {
      LinearGradient(colors: [.skyWash, .moonCream], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
        .overlay {
          Text("Second screen")
            .font(DeepType.sectionTitle)
            .foregroundStyle(.deepPlum)
        }
        .transition(.softDrift(direction))
    }

    VStack {
      Spacer()
      HStack(spacing: .rhythm) {
        Button("Back") {
          direction = .backward
          withAnimation(.hush) { showsFirst.toggle() }
        }
        Button("Forward") {
          direction = .forward
          withAnimation(.hush) { showsFirst.toggle() }
        }
      }
      .padding(.bottom, .rhythm)
    }
  }
}
#endif
