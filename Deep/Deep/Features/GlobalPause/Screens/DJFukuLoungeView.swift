import SwiftUI

/// Fuku's Lounge — the room the lobby card opens into. Mirrors the home-screen
/// recipe (stretchy hero, sections riding up over it, atmosphere, collapsible
/// header) with DJ Fuku full-bleed in the hero slot so the card's artwork
/// carries straight into the screen through the zoom. The programme below is
/// `FukuLoungeLibrary` mock content rendered inert — live lobby content
/// (countdown, participants) joins later when the pause states are combined.
///
/// Leaf screen, so it owns its screen-level styling (per the coordinator
/// rules). The close button rides in the collapsible header's trailing slot so
/// it stays reachable while the title collapses.
struct DJFukuLoungeView: View {
  var onClose: () -> Void = {}

  private let heroHeight: CGFloat = 320
  private let heroOverlap: CGFloat = 80

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyHero(media: .image(name: "DJFukuHero"), height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          onAir

          programme
            .allowsHitTesting(false)

          Color.clear.frame(height: .rhythm)
        }
        .padding(.top, -heroOverlap)
      }
    }
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.always)
    .ignoresSafeArea(edges: .top)
    .background {
      ZStack {
        // Opaque base under the atmosphere's translucent stops: nothing beneath
        // this screen may ever show through (also load-bearing mid-zoom).
        Color.moonCream.ignoresSafeArea()
        AtmosphereBackground()
      }
    }
    .collapsibleHomeHeader(
      title: "Fuku's Lounge",
      subtitle: "Lo-fi while the world gathers to pause"
    ) {
      GlassCloseButton(action: onClose)
    }
    // The feed is a preview of the room, not a library: park the inherited
    // routing and playback so nothing in the mock programme can act.
    .environment(\.openCollection, { _ in })
    .environment(\.openCollectionList, { _, _ in })
    .environment(\.soundPlayer, MockSoundPlayer.idle)
  }

  private var onAir: some View {
    OnAirPill()
      .padding(.horizontal, .edge)
  }

  private var programme: some View {
    VStack(alignment: .leading, spacing: .rhythm) {
      RecommendationsSection(
        title: "Made for the floor",
        collections: FukuLoungeLibrary.madeForTheFloor
      )

      FeatureCarousel(
        title: "Tonight's rotation",
        collections: FukuLoungeLibrary.tonightsRotation
      )

      ExploreByContentSection(categories: FukuLoungeLibrary.moods)
    }
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
