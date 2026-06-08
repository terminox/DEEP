import SwiftUI

/// The standalone home — one scroll combining a stretchy video hero, a featured
/// collection, curated carousels, and the browse-by-intention grid.
///
/// This is the leaf screen, so it owns its screen-level styling: the video hero
/// bleeds under the status bar and `AtmosphereBackground` sits behind the scroll
/// (per the project's coordinator rules, styling lives here, not in the
/// coordinator, so it actually renders).
struct DeepSoundHomeView: View {
  /// Extra bottom space so content clears the docked mini-player.
  var bottomInset: CGFloat

  private let heroHeight: CGFloat = 320
  /// How far the content rides up over the hero.
  private let heroOverlap: CGFloat = 52

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyVideoHero(height: heroHeight)

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
        .padding(.top, -heroOverlap)
      }
    }
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.always)
    .ignoresSafeArea(edges: .top)
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
  }
}

#Preview("Deep Sound — Home") {
  DeepSoundHomeView(bottomInset: .rhythm)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}
