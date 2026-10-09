#if DEBUG
import SwiftUI

/// THROWAWAY. C · Inset card — Suno.
///
/// The image is a single tall rounded card covering about 92% of the screen,
/// held in DEEP's pale sky. The title is set into the top of the card, a
/// glass action rail runs down its right edge, and a frosted controls panel
/// sits inside its bottom edge. Plum ink stays on the frosted panel.
struct InsetCardNowPlaying: View {
  var onDismiss: () -> Void

  @Environment(\.soundPlayer) private var player
  @Environment(\.nowPlayingLabKnobs) private var knobs
  @State private var showLyrics = false

  var body: some View {
    ZStack {
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground(animated: false).ignoresSafeArea()

      card
        .padding(.horizontal, knobs.cardInset)
        .padding(.top, 4)
        .padding(.bottom, knobs.cardInset)
    }
    .labLyrics(isPresented: $showLyrics)
  }

  private var card: some View {
    ZStack {
      LabArtwork(cornerRadius: .card)

      VStack(spacing: 0) {
        LabScrim(edge: .top, peak: 0.55)
          .frame(height: 200)
        Spacer()
      }
      .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))

      VStack(spacing: 0) {
        header
        Spacer(minLength: 0)
        HStack {
          Spacer()
          rail
        }
        .padding(.bottom, 14)
        panel
      }
      .padding(12)
    }
    .shadow(color: .lavenderMist.opacity(0.45), radius: 24, x: 0, y: 12)
  }

  private var header: some View {
    // Dismiss leads the title: the trailing corner belongs to the DialKit
    // button while the lab is mounted.
    HStack(alignment: .top, spacing: 12) {
      LabDismissButton(ink: .onPhoto, action: onDismiss)
      VStack(alignment: .leading, spacing: 4) {
        Text(player.currentTrack?.title ?? "")
          .font(.system(.title2, weight: .semibold))
          .foregroundStyle(LabInk.onPhoto.primary)
          .lineLimit(2)
        Text(player.collection?.title ?? "")
          .font(DeepType.body)
          .foregroundStyle(LabInk.onPhoto.secondary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 6)
    .padding(.top, 6)
  }

  private var rail: some View {
    VStack(spacing: 12) {
      LabSaveButton(ink: .onPhoto, glass: true)
      LabIconButton(systemName: "text.quote", ink: .onPhoto, glass: true, label: "Lyrics") {
        showLyrics = true
      }
    }
  }

  private var panel: some View {
    VStack(spacing: 10) {
      LabScrubber(ink: .onPale)
      HStack(spacing: 28) {
        LabSkipButton(direction: .back, ink: .onPale)
        LabPlayButton(ink: .onPale, diameter: 60, filled: false)
        LabSkipButton(direction: .forward, ink: .onPale)
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .frostedCard(cornerRadius: .card - 8)
  }
}

#Preview("C · Inset card") {
  InsetCardNowPlaying {}
    .environment(\.soundPlayer, MockSoundPlayer.playing)
}
#endif
