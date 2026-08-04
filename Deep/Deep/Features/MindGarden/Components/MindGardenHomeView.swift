import SwiftUI

/// The Mind Garden home — a personal calm space. One quiet scroll: an
/// atmospheric video header, a greeting with today's progress and streak, a
/// nudge into today's practice, and the garden growing alongside the journey.
///
/// This is the leaf screen, so it owns its screen-level styling: the video hero
/// bleeds under the status bar and `AtmosphereBackground` sits behind the scroll
/// (per the project's coordinator rules, styling lives here, not in the
/// coordinator, so it actually renders).
struct MindGardenHomeView: View {
  var state: GardenState = .sample
  /// Extra bottom space so content clears the tab bar / any docked chrome.
  var bottomInset: CGFloat = .rhythm

  /// Today's practice is a guided breath. The card stays a dumb button; the
  /// screen decides what tapping it does — here, presenting the full Deep
  /// Session flow zooming out of the card.
  @State private var isPracticePresented = false

  private let heroHeight: CGFloat = 320
  /// How far the greeting card rides up over the hero.
  private let heroOverlap: CGFloat = 52

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyHero(media: .video(resource: "deep_oak_mature"), height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          GardenGreetingCard(state: state)
            .padding(.horizontal, .edge)

          DailyPracticeCard(minutesRemaining: state.minutesRemaining) {
            isPracticePresented = true
          }
          .deepSessionLaunch(
            session: DeepSessionLibrary.balancingBreath,
            isPresented: $isPracticePresented
          )
          .padding(.horizontal, .edge)

          GrowYourGardenSection(stages: state.stages)

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
      title: "Mind Garden",
      subtitle: "Tend to your calm"
    )
  }
}

#Preview("Mind Garden — Home") {
  MindGardenHomeView(state: .sample)
}

#Preview("Mind Garden — Fresh start") {
  MindGardenHomeView(state: .fresh)
}
