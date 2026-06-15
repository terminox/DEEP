import SwiftUI

/// The community stats for a single cause: how many hearts have pooled here,
/// the share of giving it receives, and the people reached. Built on the shared
/// `ImpactCluster` so it matches the portfolio's summary exactly.
struct CategoryStatsRow: View {
  let category: CompassionCategory

  var body: some View {
    ImpactCluster(stats: [
      ImpactStat(
        label: "Hearts shared",
        value: category.heartsShared.formatted(.number.notation(.compactName)),
        symbol: "heart.fill"
      ),
      ImpactStat(
        label: "Impact allocation",
        value: "\(Int((category.allocation * 100).rounded()))%",
        symbol: "chart.pie.fill"
      ),
      ImpactStat(
        label: "People reached",
        value: category.peopleReached.formatted(.number.notation(.compactName)),
        symbol: "person.2.fill"
      ),
    ])
  }
}

#Preview("Category stats row") {
  ZStack {
    AtmosphereBackground()
    CategoryStatsRow(category: CompassionLibrary.peace)
      .padding(.edge)
  }
}
