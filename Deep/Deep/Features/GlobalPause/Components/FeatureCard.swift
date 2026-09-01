import SwiftUI

/// A large landscape card for the home's "Popular" / "Today's sessions" shelves.
/// The artwork carries the title and a duration pill; a title row sits beneath.
/// Tapping the card body pushes the collection detail via `openCollection`; the
/// play button starts the collection in place.
struct FeatureCard: View {
  @Environment(\.openCollection) private var openCollection
  @Environment(\.soundPlayer) private var player
  let collection: SoundCollection
  var width: CGFloat = 300
  var height: CGFloat = 200

  var body: some View {
    Button {
      openCollection(collection)
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        artwork
        titleRow
      }
      .frame(width: width)
    }
    .buttonStyle(.softPress)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(collection.title), \(collection.kindLabel), \(collection.totalDuration.minutesString)")
  }

  private var artwork: some View {
    ZStack(alignment: .bottomLeading) {
      SoundArtwork(palette: collection.palette, imageURL: collection.imageURL, cornerRadius: .card)
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
          Text(collection.title)
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
      Text(collection.totalDuration.minutesString)
        .font(DeepType.micro)
    }
    .foregroundStyle(.deepPlum)
    .padding(.horizontal, 9)
    .padding(.vertical, 5)
    .background(.white.opacity(0.5), in: Capsule())
  }

  private var playButton: some View {
    Button {
      player.play(collection)
    } label: {
      Image(systemName: "play.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.deepPlum)
        .frame(width: 44, height: 44)
        .background(.white.opacity(0.9), in: Circle())
        .shadow(color: .deepPlum.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("Play \(collection.title)")
  }

  private var titleRow: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 1) {
        Text(collection.title)
          .font(DeepType.body.weight(.medium))
          .foregroundStyle(.deepPlum)
          .lineLimit(1)
        Text(verbatim: "\(collection.kindLabel) · \(collection.subtitle)")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .lineLimit(1)
      }
    }
  }
}

extension SoundCollection {
  /// Small self-describing tag for home cards: any guided track makes the
  /// collection read as guided; otherwise it's a soundscape.
  var kindLabel: String {
    tracks.contains { $0.kind == .guided } ? "Guided" : "Soundscape"
  }
}

#if DEBUG
#Preview("Feature Card") {
  ZStack {
    AtmosphereBackground()
    FeatureCard(collection: SoundLibrary.calm[0])
  }
  .environment(\.soundPlayer, MockSoundPlayer.idle)
}
#endif
