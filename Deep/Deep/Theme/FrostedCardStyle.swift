import SwiftUI

struct FrostedCardBackground: View {
  var cornerRadius: CGFloat = DeepRadius.card

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(.white.opacity(0.55))
        .background(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
        )
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .strokeBorder(.white.opacity(0.45), lineWidth: 0.5)
    }
    .shadow(color: DeepColor.lavenderMist.opacity(0.18), radius: 24, x: 0, y: 12)
  }
}

extension View {
  func frostedCard(cornerRadius: CGFloat = DeepRadius.card) -> some View {
    self.background(FrostedCardBackground(cornerRadius: cornerRadius))
  }
}
