import SwiftUI

/// The standalone home — one scroll combining a featured hero, curated
/// carousels, and the browse-by-intention grid (the "merged" layout).
struct DeepSoundHomeView: View {
  /// Extra bottom space so content clears the docked mini-player.
  var bottomInset: CGFloat

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: .rhythm) {
        header

        FeaturedHeroCard(collection: SoundLibrary.featured)
          .padding(.horizontal, .edge)

        CollectionCarousel(
          title: "Continue your practice",
          collections: SoundLibrary.recent
        )

        CollectionCarousel(
          title: "Made for you",
          collections: SoundLibrary.madeForYou
        )

        IntentionGrid(intentions: SoundLibrary.intentions)

        Color.clear.frame(height: bottomInset)
      }
      .padding(.top, 8)
    }
    .scrollBounceBehavior(.basedOnSize)
    .background { AtmosphereBackground() }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Deep Sound")
        .font(DeepType.wordmark)
        .foregroundStyle(.deepPlum)
      Text("Sound to settle into")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
    }
    .padding(.horizontal, .edge)
    .padding(.top, 8)
  }
}

#Preview("Deep Sound — Home") {
  DeepSoundHomeView(bottomInset: .rhythm)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}
