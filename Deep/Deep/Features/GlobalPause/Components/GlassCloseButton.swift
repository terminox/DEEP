import SwiftUI

/// System Liquid Glass close button used to dismiss the full-screen Earth from
/// either transition prototype.
///
/// Two things make it reliably tappable over the orb (the previous attempt was
/// not): callers place it *within the safe area* and as a *top-level overlay*
/// above `Earth3DView`, so it wins hit-testing against `EarthMTKView`, which
/// captures touches across its whole bounds. The glass material matches the
/// proven iOS 26 usage in `MiniPlayerBar`, with a frosted fallback on iOS 18–25.
struct GlassCloseButton: View {
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.deepPlum)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .modifier(LiquidGlassCircle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Close")
  }
}

/// Liquid Glass on iOS 26, hand-blended frosted material on iOS 18–25.
private struct LiquidGlassCircle: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular.interactive(), in: Circle())
    } else {
      content.background(
        ZStack {
          Circle().fill(.ultraThinMaterial)
          Circle().fill(.white.opacity(0.4))
          Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
        }
      )
    }
  }
}

#Preview("Glass close button") {
  ZStack {
    AtmosphereBackground()
    GlassCloseButton(action: {})
  }
}
