import SwiftUI

/// A minimal detail leaf reached by tapping a home card. Demonstrates the
/// coordinator's `navigationDestination` end-to-end; content is intentionally
/// light until real playback is wired in.
struct HomeItemDetailView: View {
  @Environment(\.soundPlayer) private var player
  let item: HomeItem

  /// True when the shared player is currently playing *this* item.
  private var isPlayingThis: Bool {
    player.isPlaying && player.collection?.title == item.title
  }

  var body: some View {
    ScrollView {
      VStack(spacing: .rhythm) {
        HomeArtwork(palette: item.palette, cornerRadius: .card)
          .frame(height: 260)
          .overlay(alignment: .bottomLeading) {
            Text(item.kind.label.uppercased())
              .font(DeepType.micro)
              .tracking(1.4)
              .foregroundStyle(.white.opacity(0.9))
              .padding(16)
          }
          .shadow(color: .lavenderMist.opacity(0.28), radius: 22, x: 0, y: 12)

        VStack(spacing: 6) {
          Text(item.title)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
            .multilineTextAlignment(.center)
          Text("\(item.author) · \(item.durationLabel)")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        }

        playButton
      }
      .padding(.horizontal, .edge)
      .padding(.top, .rhythm)
    }
    .scrollIndicators(.hidden)
    .background { AtmosphereBackground() }
  }

  private var playButton: some View {
    Button {
      if isPlayingThis {
        player.togglePlayPause()
      } else {
        player.play(item.asSoundCollection)
      }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
        Text(isPlayingThis ? "Pause" : "Begin")
      }
      .font(DeepType.body.weight(.semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 28)
      .padding(.vertical, 13)
      .background(
        Capsule().fill(
          LinearGradient(
            colors: [.lavenderMist, .blushPowder],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
      )
      .shadow(color: .lavenderMist.opacity(0.4), radius: 10, x: 0, y: 5)
    }
    .buttonStyle(.softPress)
  }
}

#Preview("Home Item Detail") {
  HomeItemDetailView(item: HomeLibrary.popular[1])
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}
