import SwiftUI

/// A large landscape card for the home's "Popular" / "Today's sessions" shelves.
/// The artwork carries the title and a duration pill; an author row sits beneath.
/// Tapping the card body routes to detail via `openHomeItem`; the play button
/// starts the sound in place (the `FeaturedHeroCard` pattern).
struct FeatureCard: View {
  @Environment(\.openHomeItem) private var openHomeItem
  @Environment(\.soundPlayer) private var player
  let item: HomeItem
  var width: CGFloat = 300
  var height: CGFloat = 200

  var body: some View {
    Button {
      openHomeItem(item)
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        artwork
        authorRow
      }
      .frame(width: width)
    }
    .buttonStyle(.softPress)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(item.title), \(item.kind.label), \(item.durationLabel)")
  }

  private var artwork: some View {
    ZStack(alignment: .bottomLeading) {
      HomeArtwork(palette: item.palette, imageURL: item.imageURL, cornerRadius: .card)
        .frame(width: width, height: height)
        .overlay(
          LinearGradient(
            colors: [.clear, .deepPlum.opacity(0.45)],
            startPoint: .center,
            endPoint: .bottom
          )
          .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
        )

      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 8) {
          Text(item.title)
            .font(DeepType.displayTitle)
            .foregroundStyle(.white)
            .lineLimit(2)
          
          durationPill
        }
        .padding(16)
        .layoutPriority(1)
        
        playButton
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
          .padding(16)
      }
    }
    .frame(width: width, height: height)
    .shadow(color: .lavenderMist.opacity(0.28), radius: 18, x: 0, y: 12)
  }

  private var durationPill: some View {
    HStack(spacing: 4) {
      Image(systemName: "play.fill")
        .font(.system(size: 9, weight: .bold))
      Text(item.durationLabel)
        .font(DeepType.micro)
    }
    .foregroundStyle(.deepPlum)
    .padding(.horizontal, 9)
    .padding(.vertical, 5)
    .background(.white.opacity(0.5), in: Capsule())
  }

  private var playButton: some View {
    Button {
      player.play(item.asSoundCollection)
    } label: {
      Image(systemName: "play.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.deepPlum)
        .frame(width: 44, height: 44)
        .background(.white.opacity(0.9), in: Circle())
        .shadow(color: .deepPlum.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("Play \(item.title)")
  }

  private var authorRow: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 1) {
        Text(item.title)
          .font(DeepType.body.weight(.medium))
          .foregroundStyle(.deepPlum)
          .lineLimit(1)
        Text("\(item.kind.label) · \(item.author)")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .lineLimit(1)
      }
    }
  }
}

#Preview("Feature Card") {
  ZStack {
    AtmosphereBackground()
    FeatureCard(item: HomeLibrary.popular[1])
  }
  .environment(\.soundPlayer, MockSoundPlayer.idle)
}
