import SwiftUI

/// The Play / Shuffle pair that opens a listening surface — a frosted, softly
/// pressed panel button, sized to share a row. Lives here rather than inside
/// one screen because a collection and a playlist start the same way.
struct SoundActionButton: View {
  let title: String
  let systemName: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: systemName)
          .font(.system(.subheadline, weight: .semibold))
        Text(title)
          .font(DeepType.body.weight(.medium))
      }
      .foregroundStyle(.deepPlum)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 13)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(.white.opacity(0.55))
          .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .fill(.ultraThinMaterial)
          )
      )
    }
    .buttonStyle(.softPress)
  }
}

#Preview("Sound actions") {
  ZStack {
    AtmosphereBackground()
    HStack(spacing: 12) {
      SoundActionButton(title: "Play", systemName: "play.fill") {}
      SoundActionButton(title: "Shuffle", systemName: "shuffle") {}
    }
    .padding(.horizontal, .edge)
  }
}
