#if DEBUG
import SwiftUI

/// THROWAWAY. A · Canvas — Spotify Canvas / Breathwrk.
///
/// The photograph runs edge to edge under the status bar. Nothing is taken
/// away from today's player: title, save, scrubber with times, transport,
/// volume and lyrics all sit on a plum scrim over the bottom of the image.
///
/// A2 (`blurred`) is the same layout with a progressive blur under the
/// controls: the photo melts out of focus toward the bottom, so the text needs
/// a lighter plum scrim to read.
struct CanvasNowPlaying: View {
  var onDismiss: () -> Void
  var blurred = false

  @Environment(\.soundPlayer) private var player
  @Environment(\.nowPlayingLabKnobs) private var knobs
  @State private var showLyrics = false

  var body: some View {
    ZStack {
      LabArtwork()
        .ignoresSafeArea()

      VStack(spacing: 0) {
        LabScrim(edge: .top, peak: 0.45)
          .frame(height: 180)
        Spacer()
        LabScrim(edge: .bottom, peak: blurred ? 0.5 : 0.85)
          .frame(height: 520)
      }
      .ignoresSafeArea()

      VStack(spacing: 0) {
        topBar
        Spacer(minLength: 0)
        controls
      }
      .padding(.horizontal, .edge)
    }
    .labLyrics(isPresented: $showLyrics)
  }

  private var topBar: some View {
    ZStack {
      // A2 moves the collection name down to sit above the track name.
      if !blurred {
        Text(player.collection?.title ?? "")
          .font(DeepType.sectionTitle)
          .foregroundStyle(LabInk.onPhoto.primary)
          .lineLimit(1)
          .padding(.horizontal, 56)
      }
      HStack {
        if blurred {
          LabFrostedDismissButton(action: onDismiss)
        } else {
          LabDismissButton(ink: .onPhoto, action: onDismiss)
        }
        Spacer()
      }
    }
    .padding(.top, 4)
  }

  private var controls: some View {
    VStack(spacing: 18) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          if blurred {
            Text((player.collection?.title ?? "").uppercased())
              .font(DeepType.micro)
              .tracking(1.6)
              .foregroundStyle(LabInk.onPhoto.secondary)
              .lineLimit(1)
          }
          Text(player.currentTrack?.title ?? "")
            .font(.system(.title2, weight: .semibold))
            .foregroundStyle(LabInk.onPhoto.primary)
            .lineLimit(1)
          Text(player.collection?.subtitle ?? "")
            .font(DeepType.body)
            .foregroundStyle(LabInk.onPhoto.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        LabSaveButton(ink: .onPhoto)
      }

      LabScrubber(ink: .onPhoto)

      HStack {
        LabIconButton(systemName: "text.quote", ink: .onPhoto, label: "Lyrics") { showLyrics = true }
        Spacer()
        LabSkipButton(direction: .back, ink: .onPhoto)
        LabPlayButton(ink: .onPhoto, diameter: 68)
          .padding(.horizontal, 12)
        LabSkipButton(direction: .forward, ink: .onPhoto)
        Spacer()
        // Balances the lyrics button so the transport sits dead centre.
        Color.clear.frame(width: 44, height: 44)
      }

      LabVolume(ink: .onPhoto)
    }
    .padding(.bottom, 12)
    .background(alignment: .top) {
      if blurred { controlsBlur }
    }
  }

  /// A2: a progressive blur sized by the controls themselves, so its clear
  /// top edge always sits just above the track name, whatever the type size,
  /// and it runs out to both screen edges and down past the home indicator.
  private var controlsBlur: some View {
    VariableBlurView(maxBlurRadius: knobs.blurRadius, direction: .blurredBottomClearTop)
      // The UIKit view never re-reads its radius; a new identity does.
      .id(knobs.blurRadius)
      .padding(.top, -28)
      .padding(.horizontal, -.edge)
      .ignoresSafeArea(edges: .bottom)
      .allowsHitTesting(false)
  }
}

#Preview("A · Canvas") {
  CanvasNowPlaying {}
    .environment(\.soundPlayer, MockSoundPlayer.playing)
}

#Preview("A2 · Canvas + blur") {
  CanvasNowPlaying(onDismiss: {}, blurred: true)
    .environment(\.soundPlayer, MockSoundPlayer.playing)
}
#endif
