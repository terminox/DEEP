import SwiftUI

/// The running "My Hearts" balance, shown as a soft pill. The count animates
/// when hearts are sent, so giving is felt in the chrome as well as the cause.
struct HeartBalanceChip: View {
  let balance: Int
  /// Use the lighter treatment when the chip sits over a dark hero.
  var overDarkHero = false

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "heart.fill")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.blushPowder)
      Text(balance.formatted())
        .font(DeepType.caption.weight(.semibold))
        .foregroundStyle(overDarkHero ? .white : .deepPlum)
        .contentTransition(.numericText(value: Double(balance)))
        .monospacedDigit()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background {
      Capsule()
        .fill(overDarkHero ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.white.opacity(0.65)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 0.5))
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("My hearts")
    .accessibilityValue("\(balance)")
  }
}

#Preview("Heart balance chip") {
  HStack(spacing: 16) {
    HeartBalanceChip(balance: 2_450)
    HeartBalanceChip(balance: 2_450, overDarkHero: true)
      .padding(8)
      .background(.deepPlum)
  }
  .padding()
  .background(.moonCream)
}
