import SwiftUI

/// The user's balance, centred and alone: what you hold, what you've given, how
/// many causes you've touched.
///
/// This card is now the ONLY place the balance appears — there is no header
/// chip carrying it elsewhere — so it earns the card's full attention: one big
/// numeral on its own axis, not squeezed beside a ring. The pooled allocation
/// ring moved to `CommunityPoolCard`, which sits below it, so this card can
/// stay still — an altar rather than a dashboard.
struct CompassionPortfolioCard: View {
  let ledger: HeartLedger

  var body: some View {
    VStack(spacing: 20) {
      balance
      figures
    }
    .padding(.horizontal, 20)
    .padding(.top, 24)
    .padding(.bottom, 16)
    .frostedCard()
  }

  private var balance: some View {
    VStack(spacing: 6) {
      Text("MY HEARTS")
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)

      Text(ledger.balance.formatted())
        .font(DeepType.bigNumber)
        .foregroundStyle(.deepPlum)
        .monospacedDigit()
        .contentTransition(.numericText(value: Double(ledger.balance)))
        // The altar's one flourish: the frosted card's own tint recipe, re-centred
        // so the warmth gathers under the numeral instead of blooming from the
        // leading edge. Backgrounds are not clipped to their content, so the fixed
        // frame overhangs the digits and the falloff does the work.
        .background {
          RadialGradient(
            colors: [Color.blushPowder.opacity(0.32), Color.blushPowder.opacity(0)],
            center: .center,
            startRadius: 2,
            endRadius: 96
          )
          .frame(width: 196, height: 120)
          .allowsHitTesting(false)
        }

      Text(caption)
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
    }
  }

  /// A spent balance is a big centred zero. Naming what earns the next heart keeps
  /// it an invitation rather than a scoreboard loss — the same line `SendAHeartBar`
  /// already shows when the balance runs out.
  private var caption: String {
    ledger.canGive ? "hearts to give" : "practice earns more"
  }

  private var figures: some View {
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

  private func figure(
    value: String,
    label: String,
    symbol: String,
    tint: Color,
    transition: Double
  ) -> some View {
    VStack(spacing: 6) {
      Image(systemName: symbol)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(tint)
      Text(value)
        .font(DeepType.body.weight(.semibold))
        .foregroundStyle(.deepPlum)
        .monospacedDigit()
        .contentTransition(.numericText(value: transition))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(label)
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.vertical, 14)
    .padding(.horizontal, 8)
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
      CompassionPortfolioCard(ledger: .spent)
    }
    .padding(.edge)
  }
}
