import SwiftUI

/// The Compassion portfolio home — one quiet scroll that reads as a story: an
/// atmospheric hero, then the portfolio itself (what you hold, where the
/// community's hearts have gone, what you've given), the causes they flow to,
/// and finally the dispatches that show what came back.
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
          CompassionPortfolioCard(ledger: ledger)
            .padding(.horizontal, .edge)

          CausesSection(
            categories: ledger.categories,
            peopleReached: ledger.peopleReached
          )

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
    .collapsibleHomeHeader(
      title: "Compassion",
      subtitle: "Where your hearts go"
    ) {
      HeaderHeartBalance()
    }
  }
}

/// The live heart balance for the home header's trailing slot. Reads the ledger
/// and the header's over-hero state so the chip flips its light/plum treatment
/// in step with the collapsing title — keeping `CollapsibleHomeHeader` ignorant
/// of the ledger.
private struct HeaderHeartBalance: View {
  @Environment(\.heartLedger) private var ledger
  @Environment(\.headerOverDarkHero) private var overDarkHero

  var body: some View {
    HeartBalanceChip(balance: ledger.balance, overDarkHero: overDarkHero)
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
