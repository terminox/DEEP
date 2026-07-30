import SwiftUI

/// Fuku's Lounge — the room the lobby card opens into. A quiet shell for now:
/// DJ Fuku's poster floating over a blurred wash of its own artwork, the on-air
/// badge, and a line of welcome. Live lobby content (countdown, participants)
/// joins later when the pause states are combined.
///
/// Leaf screen, so it owns its screen-level styling (per the coordinator
/// rules). Under Reduce Transparency the blurred-artwork backdrop is replaced
/// wholesale by `AtmosphereBackground` — solid tokens, no live blur.
struct DJFukuLoungeView: View {
  var onClose: () -> Void = {}

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var body: some View {
    ZStack {
      // Opaque base under the atmosphere's translucent stops: nothing beneath
      // this screen may ever show through (also load-bearing mid-zoom).
      Color.moonCream.ignoresSafeArea()
      backdrop

      VStack(spacing: .rhythm) {
        Spacer()

        poster

        VStack(spacing: 10) {
          OnAirPill()
          Text("Fuku's Lounge")
            .font(DeepType.wordmark)
            .foregroundStyle(.deepPlum)
          Text("The world's next pause gathers here.\nSettle in — Fuku has the sound.")
            .font(DeepType.body)
            .foregroundStyle(.driftGrey)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, .edge)
        .accessibilityElement(children: .combine)

        Spacer()
      }
    }
    .overlay(alignment: .top) {
      // Progressive blur keeps the status bar legible over the bright backdrop.
      if !reduceTransparency {
        VariableBlurView(maxBlurRadius: 4, direction: .blurredTopClearBottom)
          .frame(height: 80)
          .ignoresSafeArea(edges: .top)
          .allowsHitTesting(false)
      }
    }
    .overlay(alignment: .topLeading) {
      GlassCloseButton(action: onClose)
        .padding(.edge)
    }
  }

  /// The artwork melted into a room-filling wash, with a cream gradient pulling
  /// the lower half back to app-native ground so the text reads at home.
  @ViewBuilder
  private var backdrop: some View {
    if reduceTransparency {
      AtmosphereBackground()
    } else {
      Color.clear
        .overlay {
          Image("DJFukuHero")
            .resizable()
            .scaledToFill()
            .blur(radius: 40)
            .scaleEffect(1.15)
        }
        .clipped()
        .ignoresSafeArea()
        .overlay {
          LinearGradient(
            colors: [Color.deepPlum.opacity(0.15), .clear, Color.moonCream.opacity(0.85)],
            startPoint: .top,
            endPoint: .bottom
          )
          .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }
  }

  private var poster: some View {
    Image("DJFukuHero")
      .resizable()
      .scaledToFit()
      .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
      .shadow(color: Color.lavenderMist.opacity(0.28), radius: 22, x: 0, y: 12)
      .padding(.horizontal, .edge)
      .accessibilityHidden(true)
  }
}

#Preview("Fuku's Lounge") {
  DJFukuLoungeView()
}

#Preview("Accessibility type") {
  DJFukuLoungeView()
    .environment(\.dynamicTypeSize, .accessibility2)
}
