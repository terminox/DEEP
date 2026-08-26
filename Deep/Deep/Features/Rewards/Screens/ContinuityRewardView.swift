import SwiftUI

/// The once-daily closing beat. It celebrates returning without introducing a
/// streak to defend: the count is continuity witnessed, never a warning.
struct ContinuityRewardView: View {
  let receipt: RewardReceipt
  /// How the return is named. A Deep Session credits today ("You returned
  /// today"); a Global Pause, which adds no practice day, witnesses the run
  /// instead ("Your rhythm continues").
  let headline: String
  let buttonTitle: String
  let onFinish: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var displayedDays: Int
  @State private var hasArrived = false
  @State private var haloReleased = false

  init(
    receipt: RewardReceipt,
    headline: String,
    buttonTitle: String,
    onFinish: @escaping () -> Void
  ) {
    self.receipt = receipt
    self.headline = headline
    self.buttonTitle = buttonTitle
    self.onFinish = onFinish
    _displayedDays = State(initialValue: receipt.continuityBefore)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: .rhythm * 1.5) {
        VStack(spacing: 7) {
          Text("YOUR RHYTHM")
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(.driftGrey)
          Text(headline)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
            .multilineTextAlignment(.center)
        }

        continuityCard
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
      RewardContinueButton(title: buttonTitle, isFinal: true, action: onFinish)
        .padding(.horizontal, .edge)
        .padding(.bottom, .rhythm)
    }
    .animation(.bloom, value: hasArrived)
    .task { await playEntrance() }
  }

  private var continuityCard: some View {
    VStack(spacing: 20) {
      ZStack {
        Circle()
          .stroke(.lavenderMist.opacity(0.38), lineWidth: 3)
          .scaleEffect(haloReleased ? 1.3 : 0.88)
          .opacity(haloReleased ? 0 : 0.7)

        Circle()
          .fill(.white.opacity(0.62))
          .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
          .padding(14)

        Image(systemName: "sun.max.fill")
          .font(.system(size: 48, weight: .light))
          .foregroundStyle(.duskRose.opacity(0.82))
      }
      .frame(width: 154, height: 154)
      .accessibilityHidden(true)

      VStack(spacing: 7) {
        Text(displayedDays.formatted())
          .font(DeepType.bigNumber)
          .foregroundStyle(.deepPlum)
          .contentTransition(.numericText(value: Double(displayedDays)))
          .monospacedDigit()

        Text(displayedDays == 1 ? "day of returning" : "days of returning")
          .font(DeepType.body)
          .foregroundStyle(.deepPlum)

        Text("Each return is enough")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 28)
    .padding(.horizontal, 20)
    .frostedCard(tint: .softLilac)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
  }

  private var accessibilitySummary: String {
    let unit = receipt.continuityAfter == 1 ? "day" : "days"
    return "\(headline). \(receipt.continuityAfter) \(unit) of returning. Each return is enough."
  }

  private func playEntrance() async {
    if reduceMotion {
      displayedDays = receipt.continuityAfter
      hasArrived = true
    } else {
      withAnimation(.bloom) { hasArrived = true }
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      withAnimation(.exhale) {
        displayedDays = receipt.continuityAfter
      } completion: {
        withAnimation(.ripple) { haloReleased = true }
      }
    }
    AccessibilityNotification.Announcement(accessibilitySummary).post()
  }
}

#Preview("Continuity reward") {
  ContinuityRewardView(
    receipt: .sample,
    headline: "You returned today",
    buttonTitle: "Carry this calm",
    onFinish: {}
  )
}

#Preview("Continuity reward — pause night") {
  ContinuityRewardView(
    receipt: .pauseNight,
    headline: "Your rhythm continues",
    buttonTitle: "Carry this calm",
    onFinish: {}
  )
}

#Preview("Continuity reward — first day") {
  ContinuityRewardView(
    receipt: .evolving,
    headline: "You returned today",
    buttonTitle: "Carry this calm",
    onFinish: {}
  )
}

#Preview("Continuity reward — large type") {
  ContinuityRewardView(
    receipt: .sample,
    headline: "You returned today",
    buttonTitle: "Carry this calm",
    onFinish: {}
  )
  .environment(\.dynamicTypeSize, .accessibility2)
}
