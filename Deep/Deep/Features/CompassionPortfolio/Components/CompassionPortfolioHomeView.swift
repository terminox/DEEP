import SwiftUI

/// The Compassion portfolio home — one quiet scroll: an atmospheric hero, the
/// user's heart balance, the causes their hearts can flow to, a summary of their
/// impact, and recent dispatches from the field.
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
        StretchyVideoHero(resource: "sky", height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          HeartsBalanceCard(balance: ledger.balance, heartsGiven: ledger.heartsGiven)
            .padding(.horizontal, .edge)

          CausesSection(categories: ledger.categories)

          ImpactSummarySection(ledger: ledger)

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
    .safeAreaInset(edge: .top) { CompassionTopBar() }
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
