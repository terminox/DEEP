import SwiftUI

/// The Compassion portfolio home — one quiet scroll that reads as a story: an
/// atmospheric hero, then what you hold, then where the community's hearts have
/// gone, then the causes they flow to, and finally the dispatches that show what
/// came back.
///
/// The rhythm is deliberate — centred card, centred card, horizontal shelf,
/// vertical list. Causes are peers you browse, so they get a shelf; dispatches
/// are a chronology you read down, so they get rows.
///
/// This is the leaf screen, so it owns its screen-level styling: the video hero
/// bleeds under the status bar and `AtmosphereBackground` sits behind the scroll
/// (per the project's coordinator rules, styling lives here, not in the
/// coordinator, so it actually renders).
struct CompassionPortfolioHomeView: View {
  @Environment(\.heartLedger) private var ledger
  /// Extra bottom space so content clears the tab bar.
  var bottomInset: CGFloat = .rhythm

  private let heroHeight: CGFloat = 320
  /// How far the balance card rides up over the hero.
  private let heroOverlap: CGFloat = 56

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyHero(media: .video(resource: "sky"), height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          // Mine, then ours. The two cards' blooms overlap at `.rhythm`, which is
          // what makes them read as one pair rather than two tallies.
          CompassionPortfolioCard(ledger: ledger)
            .padding(.horizontal, .edge)

          CommunityPoolCard(
            categories: ledger.categories,
            peopleReached: ledger.peopleReached
          )
          .padding(.horizontal, .edge)

          CausesSection(categories: ledger.categories)

          FieldReportsSection(reports: ledger.reports)

          Color.clear.frame(height: bottomInset)
        }
        .padding(.top, -heroOverlap)
      }
    }
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.always)
    .ignoresSafeArea(edges: .top)
    .background { AtmosphereBackground() }
    // No trailing balance chip: the portfolio card carries that number a few
    // points below, and "Where your hearts go" now titles the causes shelf, so
    // the header must not say it too.
    .collapsibleHomeHeader(
      title: "Compassion",
      subtitle: "Turn practice into giving"
    )
  }
}

#Preview("Compassion — Home") {
  CompassionPortfolioHomeView()
    .environment(\.heartLedger, .sample)
    .environment(\.openCategory, { _ in })
}

#Preview("Compassion — Fresh start") {
  CompassionPortfolioHomeView()
    .environment(\.heartLedger, .fresh)
    .environment(\.openCategory, { _ in })
}

/// The one state where the balance reads as a bare zero — worth its own canvas
/// now that the altar makes that number the first thing on the screen.
#Preview("Compassion — Spent") {
  CompassionPortfolioHomeView()
    .environment(\.heartLedger, .spent)
    .environment(\.openCategory, { _ in })
}
