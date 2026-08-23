import SwiftUI

/// The once-daily closing beat. It celebrates returning without introducing a
/// streak to defend: the count is continuity witnessed, never a warning.
struct DeepSessionContinuityRewardView: View {
  let receipt: DeepSessionRewardReceipt
  let onFinish: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var displayedDays: Int
  @State private var hasArrived = false
  @State private var haloReleased = false

  init(receipt: DeepSessionRewardReceipt, onFinish: @escaping () -> Void) {
    self.receipt = receipt
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
          Text("You returned today")
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
      DeepSessionRewardButton(title: "Carry this calm", action: onFinish)
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
    return "You returned today. \(receipt.continuityAfter) \(unit) of returning. Each return is enough."
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
  DeepSessionContinuityRewardView(receipt: .sample, onFinish: {})
}

#Preview("Continuity reward — first day") {
  DeepSessionContinuityRewardView(receipt: .evolving, onFinish: {})
}

#Preview("Continuity reward — large type") {
  DeepSessionContinuityRewardView(receipt: .sample, onFinish: {})
    .environment(\.dynamicTypeSize, .accessibility2)
}
