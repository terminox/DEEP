import SwiftUI

/// The floating chrome over the portfolio hero: the wordmark centred between a
/// live heart balance and a notifications bell. Mirrors `HomeTopBar` so the
/// portfolio tab feels of a piece with the rest of the app.
struct CompassionTopBar: View {
  @Environment(\.heartLedger) private var ledger

  var body: some View {
    HStack {
      HeartBalanceChip(balance: ledger.balance, overDarkHero: true)

      Spacer(minLength: 12)

      Text("Compassion")
        .font(DeepType.wordmark)
        .foregroundStyle(.white)
        .shadow(color: Color.deepPlum.opacity(0.25), radius: 6, y: 2)

      Spacer(minLength: 12)

      Button {
        // Notifications — wired when the feature exists.
      } label: {
        Image(systemName: "bell")
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.white)
          .frame(width: 40, height: 40)
          .background(.ultraThinMaterial, in: Circle())
          .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
      }
      .buttonStyle(.softPress)
      .accessibilityLabel("Notifications")
    }
    .padding(.horizontal, .edge)
    .padding(.vertical, 8)
  }
}

#Preview("Compassion top bar") {
  ZStack(alignment: .top) {
    LinearGradient(colors: [.lavenderMist, .blushPowder], startPoint: .top, endPoint: .bottom)
    CompassionTopBar()
  }
  .frame(height: 160)
  .environment(\.heartLedger, .sample)
}
