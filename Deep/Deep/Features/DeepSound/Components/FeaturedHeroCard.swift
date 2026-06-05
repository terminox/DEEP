import SwiftUI

/// The large editorial feature at the top of the home screen. The whole card
/// navigates to the collection; the play button starts it in place.
struct FeaturedHeroCard: View {
  @Environment(SoundPlayer.self) private var player
  let collection: SoundCollection

  var body: some View {
    NavigationLink(value: collection) {
      ZStack(alignment: .bottomLeading) {
        SoundArtwork(palette: collection.palette, cornerRadius: .card)
          .frame(height: 220)
          .overlay(
            LinearGradient(
              colors: [.clear, Color.deepPlum.opacity(0.28)],
              startPoint: .center,
              endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
          )

        HStack(alignment: .bottom) {
          VStack(alignment: .leading, spacing: 4) {
            Text("FEATURED")
              .font(DeepType.micro)
              .tracking(1.4)
              .foregroundStyle(.white.opacity(0.9))
            Text(collection.title)
              .font(DeepType.displayTitle)
              .foregroundStyle(.white)
            Text(collection.subtitle)
              .font(DeepType.caption)
              .foregroundStyle(.white.opacity(0.85))
          }
          Spacer()
          playButton
        }
        .padding(18)
      }
    }
    .buttonStyle(.softPress)
    .shadow(color: Color.lavenderMist.opacity(0.28), radius: 22, x: 0, y: 12)
  }

  private var playButton: some View {
    Button {
      player.play(collection)
    } label: {
      Image(systemName: "play.fill")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.deepPlum)
        .frame(width: 48, height: 48)
        .background(Circle().fill(.white.opacity(0.85)))
        .shadow(color: Color.deepPlum.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("Play \(collection.title)")
  }
}
