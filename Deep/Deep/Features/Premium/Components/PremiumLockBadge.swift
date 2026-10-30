import SwiftUI

/// The one mark DEEP Premium content wears before it is tapped: a rounded lock
/// at reduced opacity, seated in a soft translucent circle — the same white
/// seat the artwork play buttons and header icons sit in, a size down.
///
/// One component everywhere, so premium reads the same on a shelf tile, a home
/// card, a list row, a playlist row, and inline in a collection's track list.
/// Callers decide *whether* to show it, always through `PremiumGate`.
struct PremiumLockBadge: View {
  /// The circle's diameter. The glyph scales with it.
  var diameter: CGFloat = 28

  var body: some View {
    Image(systemName: "lock.fill")
      .font(.system(size: diameter * 0.42, weight: .semibold))
      .fontDesign(.rounded)
      .foregroundStyle(Color.deepPlum.opacity(0.7))
      .frame(width: diameter, height: diameter)
      .background {
        Circle()
          .fill(.white.opacity(0.65))
          .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.5))
      }
      .accessibilityElement()
      .accessibilityLabel("Part of DEEP Premium")
  }
}

extension View {
  /// Seats the lock badge in a corner of a piece of artwork when `isLocked`.
  /// Nothing is drawn otherwise, so subscribing removes it in place.
  func premiumLockBadge(
    _ isLocked: Bool,
    diameter: CGFloat = 28,
    alignment: Alignment = .topTrailing,
    inset: CGFloat = 8
  ) -> some View {
    overlay(alignment: alignment) {
      if isLocked {
        PremiumLockBadge(diameter: diameter)
          .padding(inset)
          .transition(.opacity)
      }
    }
    .animation(.settle, value: isLocked)
  }
}

#Preview("Premium lock badge") {
  VStack(spacing: 24) {
    HStack(spacing: 16) {
      PremiumLockBadge(diameter: 20)
      PremiumLockBadge(diameter: 22)
      PremiumLockBadge()
    }
    SoundArtwork(palette: .aurora, imageURL: nil)
      .frame(width: 150, height: 150)
      .premiumLockBadge(true)
  }
  .padding()
  .background { AtmosphereBackground() }
}
