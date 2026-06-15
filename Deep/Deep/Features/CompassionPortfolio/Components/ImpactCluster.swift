import SwiftUI

/// A row of headline figures on a frosted surface, separated by hairline rules.
/// Reused for the portfolio's "your impact" summary and the cause detail's
/// community stats, so impact reads identically in both places.
struct ImpactCluster: View {
  let stats: [ImpactStat]

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
        if index > 0 {
          Rectangle()
            .fill(.lavenderMist.opacity(0.22))
            .frame(width: 1, height: 40)
        }
        column(for: stat)
          .frame(maxWidth: .infinity)
      }
    }
    .padding(.vertical, 18)
    .padding(.horizontal, 16)
    .frostedCard()
  }

  private func column(for stat: ImpactStat) -> some View {
    VStack(spacing: 6) {
      Image(systemName: stat.symbol)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.lavenderMist)
      Text(stat.value)
        .font(DeepType.counter)
        .foregroundStyle(.deepPlum)
        .monospacedDigit()
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(stat.label)
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview("Impact cluster") {
  ZStack {
    AtmosphereBackground()
    ImpactCluster(stats: [
      ImpactStat(label: "Hearts given", value: "318", symbol: "heart.fill"),
      ImpactStat(label: "People reached", value: "586K", symbol: "person.2.fill"),
      ImpactStat(label: "Causes supported", value: "5", symbol: "hand.raised.fill"),
    ])
    .padding(.edge)
  }
}
