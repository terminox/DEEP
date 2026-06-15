import SwiftUI

/// A small flourish for the one-tap heart: each time `trigger` changes, a heart
/// rises from the anchor and fades, so sending feels alive. Honours Reduce Motion
/// by skipping the float.
private struct HeartBurstModifier: ViewModifier {
  let trigger: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var rise: CGFloat = 0
  @State private var opacity: CGFloat = 0

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .center) {
        Image(systemName: "heart.fill")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(.blushPowder)
          .opacity(opacity)
          .offset(y: rise)
          .allowsHitTesting(false)
      }
      .onChange(of: trigger) {
        guard trigger > 0 else { return }
        if reduceMotion {
          opacity = 0
          return
        }
        rise = 0
        opacity = 1
        withAnimation(.exhale) {
          rise = -44
          opacity = 0
        }
      }
  }
}

extension View {
  /// Floats a heart upward from this view whenever `trigger` increments.
  func heartBurst(trigger: Int) -> some View {
    modifier(HeartBurstModifier(trigger: trigger))
  }
}

#Preview("Heart burst") {
  @Previewable @State var count = 0
  Button("Send") { count += 1 }
    .padding(60)
    .heartBurst(trigger: count)
    .background(.moonCream)
}
