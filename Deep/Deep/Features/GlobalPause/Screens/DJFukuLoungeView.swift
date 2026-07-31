import SwiftUI

/// Fuku's Lounge — the room the lobby card opens into, pushed onto the Global
/// Pause nav stack like any other leaf (system back button, no custom chrome).
/// Mirrors the home-screen recipe: DJ Fuku full-bleed in the stretchy hero
/// slot under the transparent bar, sections riding up over it, atmosphere
/// behind. The programme below is `FukuLoungeLibrary` mock content rendered
/// inert — live lobby content (countdown, participants) joins later when the
/// pause states are combined.
///
/// Leaf screen, so it owns its screen-level styling (per the coordinator
/// rules); navigation chrome is the system bar the coordinator un-hides for
/// pushed screens.
struct DJFukuLoungeView: View {
  /// The shared Global Pause card, borrowed from the home feed while the
  /// lounge is open (see `GlobalPauseCardSlotView.Role.guest`). `nil` keeps
  /// previews hermetic and Metal-free.
  var card: GlobalPauseCardView? = nil

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  private let heroHeight: CGFloat = 320
  private let heroOverlap: CGFloat = 80

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyHero(media: .image(name: "DJFukuHero"), height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          onAir

          if let card {
            GlobalPauseCardSlot(card: card, role: .guest)
              .frame(height: 200)
              .padding(.horizontal, .edge)
          }

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
        // this screen may ever show through.
        Color.moonCream.ignoresSafeArea()
        AtmosphereBackground()
      }
    }
    .overlay(alignment: .top) {
      // Progressive blur keeps the status bar, inline title, and back chevron
      // legible over the bright hero art.
      if !reduceTransparency {
        VariableBlurView(maxBlurRadius: 4, direction: .blurredTopClearBottom)
          .frame(height: 80)
          .ignoresSafeArea(edges: .top)
          .allowsHitTesting(false)
      }
    }
    .navigationTitle("Fuku's Lounge")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
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
