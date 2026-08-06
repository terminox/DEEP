import SwiftUI

/// A group of headline figures on a frosted surface. Each figure sits on its own
/// inset tonal panel, so the group reads by *surface* rather than by the hairline
/// rules a stat row usually leans on — the separator this project doesn't draw.
struct ImpactPebbles: View {
  let stats: [ImpactStat]

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      ForEach(stats) { stat in
        StatPebble(stat: stat)
      }
    }
    // Lets each pebble stretch to the tallest sibling (so a two-line label never
    // leaves a ragged row) without the group itself claiming spare height.
    .fixedSize(horizontal: false, vertical: true)
    .padding(10)
    .frostedCard()
  }
}

/// One figure on its own panel: glyph, value, label.
struct StatPebble: View {
  let stat: ImpactStat

  var body: some View {
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
        .minimumScaleFactor(0.6)
      Text(stat.label)
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.vertical, 16)
    .padding(.horizontal, 6)
    .pebble()
    .accessibilityElement(children: .combine)
  }
}

extension View {
  /// The inset tonal panel that groups content inside a frosted card. Wherever a
  /// rule would normally divide, this defines the group instead.
  func pebble(cornerRadius: CGFloat = .tile) -> some View {
    self.background(
      .white.opacity(0.38),
      in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    )
  }
}

#Preview("Impact pebbles") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      ImpactPebbles(stats: [
        ImpactStat(label: "Hearts pooled", value: "16.2K", symbol: "heart.fill"),
        ImpactStat(label: "People reached", value: "96K", symbol: "person.2.fill"),
        ImpactStat(label: "Share of giving", value: "24%", symbol: "chart.pie.fill"),
      ])
    }
    .padding(.edge)
  }
}
