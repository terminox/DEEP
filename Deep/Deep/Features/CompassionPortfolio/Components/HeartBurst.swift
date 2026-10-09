import SwiftUI

/// A small flourish for the one-tap heart: each time `trigger` changes, a heart
/// blooms out of the anchor and drifts away, so sending feels alive — paired with
/// a light haptic, since giving is the feature's one moment worth feeling.
///
/// The heart starts just clear of the anchor and small, rather than full-size
/// behind it, so the bloom is visible from its first frame. Honours Reduce Motion
/// by skipping the float; the haptic still fires.
private struct HeartBurstModifier: ViewModifier {
  let trigger: Int
  /// False when the caller feels the moment through its own haptic — see
  /// `heartHaptic(for:)`, which keeps a listen's heart to one tap however
  /// many surfaces bloom it.
  let haptic: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var rise: CGFloat = 0
  @State private var scale: CGFloat = 0.6
  @State private var opacity: CGFloat = 0

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .top) {
        Image(systemName: "heart.fill")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(.blushPowder)
          .shadow(color: Color.lavenderMist.opacity(0.4), radius: 8, y: 2)
          .scaleEffect(scale)
          .opacity(opacity)
          .offset(y: rise)
          .allowsHitTesting(false)
      }
      .sensoryFeedback(.impact(weight: .light), trigger: trigger) { _, _ in haptic }
      .onChange(of: trigger) {
        guard trigger > 0 else { return }
        if reduceMotion {
          opacity = 0
          return
        }
        rise = -6
        scale = 0.6
        opacity = 1
        withAnimation(.exhale) {
          rise = -50
          scale = 1.05
          opacity = 0
        }
      }
  }
}

extension View {
  /// Blooms a heart out of this view whenever `trigger` increments — with
  /// its light haptic unless `haptic` is false.
  func heartBurst(trigger: Int, haptic: Bool = true) -> some View {
    modifier(HeartBurstModifier(trigger: trigger, haptic: haptic))
  }

  /// The burst's light haptic alone, each time `trigger` increments — for a
  /// surface too tight to show the bloom but still worth feeling.
  func heartBurstHaptic(trigger: Int) -> some View {
    sensoryFeedback(.impact(weight: .light), trigger: trigger)
  }
}

#if DEBUG
#Preview("Heart burst") {
  @Previewable @State var count = 0
  Button("Send") { count += 1 }
    .padding(60)
    .heartBurst(trigger: count)
    .background(.moonCream)
}
#endif
