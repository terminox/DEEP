import SwiftUI

/// The standalone home — one scroll combining a stretchy video hero, the
/// Breathe doorway into Deep Session, and five category carousels.
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
  private let heroOverlap: CGFloat = 80

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyVideoHero(resource: "sky", height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          BreatheHeroCard(session: DeepSessionLibrary.balancingBreath)
            .padding(.horizontal, .edge)

          CollectionCarousel(
            title: "Calm",
            collections: SoundLibrary.calm
          )

          CollectionCarousel(
            title: "Morning",
            collections: SoundLibrary.morning
          )

          CollectionCarousel(
            title: "Sleep",
            collections: SoundLibrary.sleep
          )

          CollectionCarousel(
            title: "Deep Teacher",
            collections: SoundLibrary.deepTeacher
          )

          CollectionCarousel(
            title: "Deep Kids",
            collections: SoundLibrary.deepKids
          )

          Color.clear.frame(height: bottomInset)
        }
        .padding(.top, -heroOverlap)
      }
    }
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.always)
    .ignoresSafeArea(edges: .top)
    .background { AtmosphereBackground() }
    .collapsibleHomeHeader(
      title: "Deep Sound",
      subtitle: "Breathe and listen"
    )
  }
}

#Preview("Deep Sound — Home") {
  DeepSoundHomeView(bottomInset: .rhythm)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}
