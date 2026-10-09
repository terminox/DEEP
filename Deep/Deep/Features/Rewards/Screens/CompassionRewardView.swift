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
          Text(title)
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
        // Absent while the night's award is still on its way: nothing to
        // promise, and the day isn't full.
        if let rewardLine {
          Text(rewardLine)
            // The explanation is a sentence, not a figure — it reads at body
            // size, like the balance line beneath it.
            .font(receipt.explainsMissedAttendance ? DeepType.body : DeepType.displayTitle)
            .foregroundStyle(receipt.heartsAwarded > 0 ? .duskRose : .deepPlum)
            .multilineTextAlignment(.center)
        }

        Text(Self.balanceLine(displayedBalance))
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

  private var title: String {
    if receipt.heartsAwarded > 0 {
      return String(localized: "Kindness carried forward", bundle: .app, locale: .app)
    }
    // A pause night the server didn't count — or hasn't answered for yet —
    // is not a full day: say so honestly rather than blame the ceiling.
    if receipt.explainsMissedAttendance || receipt.awaitsAttendanceAward {
      return String(localized: "Thank you for pausing", bundle: .app, locale: .app)
    }
    return String(localized: "A full day", bundle: .app, locale: .app)
  }

  /// The line under the motif; nil while the night's award is still unknown.
  private var rewardLine: String? {
    if receipt.explainsMissedAttendance {
      return String(localized: "Stay through the meditation to receive hearts", bundle: .app, locale: .app)
    }
    if receipt.awaitsAttendanceAward { return nil }
    guard receipt.heartsAwarded > 0 else {
      return String(localized: "Today is full", bundle: .app, locale: .app)
    }
    return receipt.heartsAwarded == 1
      ? String(localized: "+1 heart", bundle: .app, locale: .app)
      : String(localized: "+\(receipt.heartsAwarded) hearts", bundle: .app, locale: .app)
  }

  private static func balanceLine(_ balance: Int) -> String {
    balance == 1
      ? String(localized: "1 heart ready to give", bundle: .app, locale: .app)
      : String(
        localized: "\(balance.formatted(.number.locale(.app))) hearts ready to give",
        bundle: .app,
        locale: .app
      )
  }

  private var todayLine: String {
    String(
      localized: "\(displayedToday) of \(HeartLedger.dailyEarnCeiling) received today",
      bundle: .app,
      locale: .app
    )
  }

  private var accessibilitySummary: String {
    let balance = Self.balanceLine(receipt.heartBalanceAfter)
    if receipt.heartsAwarded > 0 {
      let received = receipt.heartsAwarded == 1
        ? String(localized: "1 heart received", bundle: .app, locale: .app)
        : String(localized: "\(receipt.heartsAwarded) hearts received", bundle: .app, locale: .app)
      return "\(received). \(balance)."
    }
    if let rewardLine, receipt.explainsMissedAttendance {
      return "\(title). \(rewardLine). \(balance)."
    }
    if let rewardLine {
      return "\(rewardLine). \(balance)."
    }
    return "\(title). \(balance)."
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

#Preview("Compassion reward — pause claim on its way") {
  CompassionRewardView(
    receipt: .pausePending,
    buttonTitle: "Carry this calm",
    isFinal: true,
    onContinue: {}
  )
}

#Preview("Compassion reward — pause missed") {
  CompassionRewardView(
    receipt: .pauseMissed,
    buttonTitle: "Carry this calm",
    isFinal: true,
    onContinue: {}
  )
}
