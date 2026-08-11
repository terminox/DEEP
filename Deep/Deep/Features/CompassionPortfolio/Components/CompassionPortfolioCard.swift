import SwiftUI

/// The portfolio in one card, riding up over the hero: what you hold, where the
/// community's hearts have gone, and what you've given.
///
/// It leads the screen because the balance alone doesn't — the header chip
/// already carries that number. Pairing it with the allocation halo makes the
/// word "portfolio" literal, and folding the personal figures in underneath
/// keeps reflection beside the balance instead of interrupting the causes.
struct CompassionPortfolioCard: View {
  let ledger: HeartLedger

  private var segments: [RingSegment] { .allocation(of: ledger.categories) }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .center, spacing: 16) {
        balance
        Spacer(minLength: 8)
        halo
      }

      Text("Earned in practice. Send them to a cause and we give, for real, on your behalf.")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .fixedSize(horizontal: false, vertical: true)

      // Two inset panels close the card. The tonal surface is what groups them —
      // where a card like this usually draws a rule.
      HStack(spacing: 10) {
        figure(
          value: ledger.heartsGiven.formatted(),
          label: "HEARTS GIVEN",
          symbol: "heart.circle.fill",
          tint: .blushPowder,
          transition: Double(ledger.heartsGiven)
        )
        figure(
          value: ledger.causesSupported.formatted(),
          label: "CAUSES",
          symbol: "hands.and.sparkles.fill",
          tint: .lavenderMist,
          transition: Double(ledger.causesSupported)
        )
      }
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20)
    .frostedCard()
  }

  private var balance: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("MY HEARTS")
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)
      Text(ledger.balance.formatted())
        .font(DeepType.bigNumber)
        .foregroundStyle(.deepPlum)
        .contentTransition(.numericText(value: Double(ledger.balance)))
        .monospacedDigit()
      Text("to give")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
    }
  }

  /// The community's pooled hearts, divided across the causes they went to —
  /// live, so an arc grows the moment a heart is sent.
  private var halo: some View {
    ZStack {
      CompassionRing(segments: segments, lineWidth: 11)
      VStack(spacing: 1) {
        Text(ledger.heartsPooled.formatted(.number.notation(.compactName)))
          .font(DeepType.counter)
          .foregroundStyle(.deepPlum)
          .monospacedDigit()
          .contentTransition(.numericText(value: Double(ledger.heartsPooled)))
        Text("POOLED")
          .font(DeepType.micro)
          .tracking(1.2)
          .foregroundStyle(.driftGrey)
      }
    }
    .frame(width: 88, height: 88)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Where the community's hearts have gone")
    .accessibilityValue(haloDescription)
  }

  private var haloDescription: String {
    let total = max(ledger.heartsPooled, 1)
    let shares = ledger.categories.map { category in
      "\(category.name) \(Int((Double(category.heartsShared) / Double(total) * 100).rounded())) percent"
    }
    return "\(ledger.heartsPooled) hearts pooled. " + shares.joined(separator: ", ")
  }

  private func figure(
    value: String,
    label: String,
    symbol: String,
    tint: Color,
    transition: Double
  ) -> some View {
    HStack(spacing: 9) {
      Image(systemName: symbol)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(tint)
      VStack(alignment: .leading, spacing: 1) {
        Text(value)
          .font(DeepType.body.weight(.semibold))
          .foregroundStyle(.deepPlum)
          .monospacedDigit()
          .contentTransition(.numericText(value: transition))
        Text(label)
          .font(DeepType.micro)
          .tracking(1.2)
          .foregroundStyle(.driftGrey)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .pebble()
    .accessibilityElement(children: .combine)
  }
}

#Preview("Portfolio card") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      CompassionPortfolioCard(ledger: .sample)
      CompassionPortfolioCard(ledger: .fresh)
    }
    .padding(.edge)
  }
}
