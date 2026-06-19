import SwiftUI

/// The shared bottom chrome for the grand Global Pause cards: a cream legibility
/// scrim under the title, a short caption, and a non-interactive "Join now" pill.
///
/// Used by both transition prototypes — `GlobalPauseZoomCard` (App Store `.zoom`)
/// and the coordinator's hero-expansion overlay — so the two cards look identical
/// apart from their differentiating caption. The pill is intentionally a styled
/// label, not a `Button`: the whole card is the tap target.
struct GlobalPauseCardChrome: View {
  /// Differentiator shown under the title while we A/B the two transitions.
  var caption: String

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      // Soft cream lift so the copy stays legible over the orb.
      LinearGradient(
        colors: [.clear, Color.moonCream.opacity(0.85)],
        startPoint: .center,
        endPoint: .bottom
      )

      VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Global Pause")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          Text(caption)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        }

        joinPill
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var joinPill: some View {
    HStack(spacing: 6) {
      Image(systemName: "heart.fill")
        .font(.system(.footnote, design: .rounded, weight: .semibold))
      Text("Join now")
        .font(DeepType.body.weight(.medium))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 22)
    .padding(.vertical, 11)
    .background(
      Capsule().fill(
        LinearGradient(
          colors: [.lavenderMist, .blushPowder],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
    )
    .shadow(color: Color.lavenderMist.opacity(0.4), radius: 10, x: 0, y: 5)
  }
}

#Preview("Card chrome") {
  ZStack {
    AtmosphereBackground()
    GlobalPauseCardChrome(caption: "Breathe with the world, together")
      .frame(height: 340)
      .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
      .padding(.horizontal, .edge)
  }
}
