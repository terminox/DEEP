import SwiftUI

/// The portfolio's "your impact" summary — the user's giving distilled into
/// three figures, built from the live ledger.
struct ImpactSummarySection: View {
  let ledger: HeartLedger

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "Your impact")

      ImpactCluster(stats: [
        ImpactStat(
          label: "Hearts given",
          value: ledger.heartsGiven.formatted(),
          symbol: "heart.fill"
        ),
        ImpactStat(
          label: "People reached",
          value: ledger.peopleReached.formatted(.number.notation(.compactName)),
          symbol: "person.2.fill"
        ),
        ImpactStat(
          label: "Causes supported",
          value: ledger.causesSupported.formatted(),
          symbol: "hand.raised.fill"
        ),
      ])
      .padding(.horizontal, .edge)
    }
  }
}

#Preview("Impact summary") {
  ScrollView {
    ImpactSummarySection(ledger: .sample)
      .padding(.vertical)
  }
  .background { AtmosphereBackground() }
}
