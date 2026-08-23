import SwiftUI

/// The second reward: practice becomes a heart the member can give outward.
/// The portfolio's daily halo is reduced to the earned change and live balance.
struct CompassionRewardView: View {
  let receipt: RewardReceipt
  let buttonTitle: String
  /// Whether this step closes the ritual — the button reads its hint from this.
  let isFinal: Bool
  let onContinue: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var displayedBalance: Int
  @State private var displayedToday: Int
  @State private var heartFlourish = 0
  @State private var hasArrived = false

  init(
    receipt: RewardReceipt,
    buttonTitle: String,
    isFinal: Bool = false,
    onContinue: @escaping () -> Void
  ) {
    self.receipt = receipt
    self.buttonTitle = buttonTitle
    self.isFinal = isFinal
    self.onContinue = onContinue
    _displayedBalance = State(initialValue: receipt.heartBalanceBefore)
    _displayedToday = State(initialValue: receipt.heartsEarnedTodayBefore)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: .rhythm * 1.5) {
        VStack(spacing: 7) {
          Text("COMPASSION")
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(.driftGrey)
          Text(receipt.heartsAwarded > 0 ? "Kindness carried forward" : "A full day")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
            .multilineTextAlignment(.center)
        }

        compassionCard
          .opacity(hasArrived ? 1 : 0)
          .scaleEffect(reduceMotion || hasArrived ? 1 : 0.92)
          .offset(y: reduceMotion || hasArrived ? 0 : 14)
      }
      .frame(maxWidth: .infinity)
      .containerRelativeFrame(.vertical, alignment: .center)
      .padding(.horizontal, .edge)
      .padding(.vertical, .rhythm)
    }
    .scrollIndicators(.hidden)
    .safeAreaInset(edge: .bottom) {
      RewardContinueButton(title: buttonTitle, isFinal: isFinal, action: onContinue)
        .padding(.horizontal, .edge)
        .padding(.bottom, .rhythm)
    }
    .animation(.bloom, value: hasArrived)
    .task { await playEntrance() }
  }

  private var compassionCard: some View {
    VStack(spacing: 18) {
      ZStack {
        CompassionRing(
          segments: [RingSegment(share: todayProgress, colors: [.lavenderMist, .blushPowder])],
          lineWidth: 6,
          gap: 0
        )
        CompassionMotif(
          symbol: "heart.fill",
          palette: .dusk,
          cornerRadius: .chip,
          symbolScale: 0.38
        )
        .padding(17)
      }
      .frame(width: 154, height: 154)
      .heartBurst(trigger: heartFlourish)
      .accessibilityHidden(true)

      VStack(spacing: 7) {
        Text(rewardLine)
          .font(DeepType.displayTitle)
          .foregroundStyle(receipt.heartsAwarded > 0 ? .duskRose : .deepPlum)

        Text(balanceLine)
          .font(DeepType.body)
          .foregroundStyle(.deepPlum)
          .contentTransition(.numericText(value: Double(displayedBalance)))
          .monospacedDigit()

        Text(todayLine)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .contentTransition(.numericText(value: Double(displayedToday)))
          .monospacedDigit()
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 28)
    .padding(.horizontal, 20)
    .frostedCard(tint: .blushPowder)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
  }

  private var todayProgress: Double {
    Double(displayedToday) / Double(HeartLedger.dailyEarnCeiling)
  }

  private var rewardLine: String {
    guard receipt.heartsAwarded > 0 else { return "Today is full" }
    let unit = receipt.heartsAwarded == 1 ? "heart" : "hearts"
    return "+\(receipt.heartsAwarded) \(unit)"
  }

  private var balanceLine: String {
    displayedBalance == 1
      ? "1 heart ready to give"
      : "\(displayedBalance.formatted()) hearts ready to give"
  }

  private var todayLine: String {
    "\(displayedToday.formatted()) of \(HeartLedger.dailyEarnCeiling) received today"
  }

  private var accessibilitySummary: String {
    if receipt.heartsAwarded > 0 {
      let unit = receipt.heartsAwarded == 1 ? "heart" : "hearts"
      return "\(receipt.heartsAwarded) \(unit) received. \(receipt.heartBalanceAfter) hearts ready to give."
    }
    return "Today is full. \(receipt.heartBalanceAfter) hearts ready to give."
  }

  private func playEntrance() async {
    if reduceMotion {
      settleImmediately()
      hasArrived = true
      if receipt.heartsAwarded > 0 { heartFlourish += 1 }
    } else {
      withAnimation(.bloom) { hasArrived = true }
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      withAnimation(.exhale) {
        settleImmediately()
      } completion: {
        if receipt.heartsAwarded > 0 { heartFlourish += 1 }
      }
    }
    AccessibilityNotification.Announcement(accessibilitySummary).post()
  }

  private func settleImmediately() {
    displayedBalance = receipt.heartBalanceAfter
    displayedToday = receipt.heartsEarnedTodayAfter
  }
}

#Preview("Compassion reward") {
  CompassionRewardView(receipt: .sample, buttonTitle: "Continue", onContinue: {})
}

#Preview("Compassion reward — final") {
  CompassionRewardView(
    receipt: .laterToday,
    buttonTitle: "Carry this calm",
    isFinal: true,
    onContinue: {}
  )
}

#Preview("Compassion reward — capped") {
  CompassionRewardView(
    receipt: .capped,
    buttonTitle: "Carry this calm",
    isFinal: true,
    onContinue: {}
  )
}

#Preview("Compassion reward — pause night") {
  CompassionRewardView(receipt: .pauseNight, buttonTitle: "Continue", onContinue: {})
}
