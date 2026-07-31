import SwiftUI

/// Deep's breathing skeleton primitives — never a shimmer-sweep or spinner.
/// Screen-specific skeleton layouts compose `SkeletonBlock` / `SkeletonTextLine`
/// to mirror real content geometry, then apply `.skeletonBreath()` once at the root.

struct SkeletonBlock: View {
  var cornerRadius: CGFloat = .tile

  var body: some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .fill(.white.opacity(0.55))
  }
}

struct SkeletonTextLine: View {
  var width: CGFloat? = nil

  var body: some View {
    Capsule()
      .fill(.white.opacity(0.55))
      .frame(maxWidth: width ?? .infinity)
      .frame(width: width, height: 12)
  }
}

// MARK: - Breathing

private struct SkeletonBreathModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var breathing = false

  func body(content: Content) -> some View {
    content
      .opacity(reduceMotion ? 0.65 : (breathing ? 0.85 : 0.45))
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Loading")
      .onAppear {
        guard !reduceMotion else { return }
        withAnimation(.breath(over: 2.6).repeatForever(autoreverses: true)) {
          breathing = true
        }
      }
  }
}

extension View {
  /// Pulses the whole subtree's opacity in unison, as one slow breath. Apply
  /// once at a skeleton layout's root — never per-block. Honours Reduce Motion
  /// by holding still at a mid opacity, and collapses VoiceOver's traversal of
  /// the empty shapes into a single "Loading" announcement.
  func skeletonBreath() -> some View {
    modifier(SkeletonBreathModifier())
  }
}

#Preview("Skeleton block") {
  ZStack {
    Color.moonCream.ignoresSafeArea()

    VStack(alignment: .leading, spacing: .rhythm) {
      SkeletonBlock()
        .frame(width: 150, height: 150)

      SkeletonTextLine(width: 120)
      SkeletonTextLine()
    }
    .padding(.edge)
    .skeletonBreath()
  }
}
