import SwiftUI

/// A circular glyph button for a home header's trailing slot — the icon twin of
/// `HeartBalanceChip`, in the treatment that chip wears once it has landed:
/// plum on white, with the same hairline.
///
/// One treatment only. The over-the-hero variant (white on `.ultraThinMaterial`)
/// belongs to headers that float over a dark video; this button is used on
/// `pinnedHomeHeader`, which has no hero, so a second variant would be a
/// promise nothing keeps.
struct HeaderIconButton: View {
  let systemName: String
  let accessibilityLabel: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.deepPlum)
        .frame(width: 40, height: 40)
        .background {
          Circle()
            .fill(.white.opacity(0.65))
            .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.5))
        }
        .contentShape(Circle())
    }
    .buttonStyle(.softPress)
    .accessibilityLabel(accessibilityLabel)
  }
}

#Preview("Header icon button") {
  ZStack {
    AtmosphereBackground()
    HeaderIconButton(systemName: "gearshape", accessibilityLabel: "Settings") {}
  }
}
