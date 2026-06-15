import SwiftUI

/// The portfolio's centrepiece — the user's heart balance riding up over the
/// hero. A frosted surface lets the dawn colours glow through; the big number
/// animates as hearts are sent, so the act of giving registers right here.
struct HeartsBalanceCard: View {
  let balance: Int
  let heartsGiven: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("MY HEARTS")
            .font(DeepType.micro)
            .tracking(1.4)
            .foregroundStyle(.driftGrey)
          Text(balance.formatted())
            .font(DeepType.bigNumber)
            .foregroundStyle(.deepPlum)
            .contentTransition(.numericText(value: Double(balance)))
            .monospacedDigit()
        }
        Spacer(minLength: 12)
        heartBadge
      }

      Text("Earned through your practice. Send them to a cause you believe in — we donate for real on your behalf.")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .fixedSize(horizontal: false, vertical: true)

      Rectangle()
        .fill(.lavenderMist.opacity(0.22))
        .frame(height: 1)

      HStack(spacing: 6) {
        Image(systemName: "heart.circle.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.blushPowder)
        Text("\(heartsGiven.formatted()) hearts given so far")
          .font(DeepType.caption.weight(.medium))
          .foregroundStyle(.deepPlum)
          .contentTransition(.numericText(value: Double(heartsGiven)))
      }
    }
    .padding(20)
    .frostedCard()
  }

  private var heartBadge: some View {
    Image(systemName: "heart.fill")
      .font(.system(size: 22, weight: .semibold))
      .foregroundStyle(
        LinearGradient(colors: [.lavenderMist, .blushPowder], startPoint: .top, endPoint: .bottom)
      )
      .frame(width: 52, height: 52)
      .background(.white.opacity(0.6), in: Circle())
      .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
  }
}

#Preview("Hearts balance card") {
  ZStack {
    AtmosphereBackground()
    HeartsBalanceCard(balance: 2_450, heartsGiven: 318)
      .padding(.edge)
  }
}
