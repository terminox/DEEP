import SwiftUI

struct FrostedCardBackground: View {
  var cornerRadius: CGFloat = .card
  /// Optional identity wash bloomed from the leading edge — lets a card carry
  /// the colour of the thing it stands for (a cause, a collection) without
  /// leaving the frosted family. `nil` keeps the plain surface.
  var tint: Color? = nil

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    ZStack {
      shape
        .fill(.white.opacity(0.55))
        .background(shape.fill(.ultraThinMaterial))
      if let tint {
        shape.fill(
          RadialGradient(
            colors: [tint.opacity(0.36), tint.opacity(0)],
            center: .leading,
            startRadius: 0,
            endRadius: 240
          )
        )
      }
      shape.strokeBorder(.white.opacity(0.45), lineWidth: 0.5)
    }
    .shadow(color: Color.lavenderMist.opacity(0.18), radius: 24, x: 0, y: 12)
  }
}

extension View {
  func frostedCard(cornerRadius: CGFloat = .card, tint: Color? = nil) -> some View {
    self.background(FrostedCardBackground(cornerRadius: cornerRadius, tint: tint))
  }
}
