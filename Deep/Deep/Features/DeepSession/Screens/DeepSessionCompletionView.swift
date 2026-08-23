import SwiftUI

/// Conducts the rewarding end of a finished Deep Session. The sequence only
/// moves forward: garden, compassion, then the once-daily continuity beat.
struct DeepSessionCompletionView: View {
  private enum Step {
    case garden
    case compassion
    case continuity
  }

  let receipt: DeepSessionRewardReceipt
  var onFinish: () -> Void = {}

  @State private var step = Step.garden
  @State private var isTransitioning = false

  var body: some View {
    ZStack {
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()

      switch step {
      case .garden:
        DeepSessionGardenRewardView(
          receipt: receipt,
          buttonTitle: "Continue",
          onContinue: showCompassion
        )
        .transition(.softDrift)

      case .compassion:
        if receipt.showsContinuity {
          DeepSessionCompassionRewardView(
            receipt: receipt,
            buttonTitle: "Continue",
            onContinue: showContinuity
          )
          .transition(.softDrift)
        } else {
          DeepSessionCompassionRewardView(
            receipt: receipt,
            buttonTitle: "Carry this calm",
            onContinue: finish
          )
          .transition(.softDrift)
        }

      case .continuity:
        DeepSessionContinuityRewardView(
          receipt: receipt,
          onFinish: finish
        )
        .transition(.softDrift)
      }
    }
  }

  private func showCompassion() {
    move(to: .compassion)
  }

  private func showContinuity() {
    move(to: .continuity)
  }

  private func move(to nextStep: Step) {
    guard !isTransitioning else { return }
    isTransitioning = true
    withAnimation(.hush) {
      step = nextStep
    } completion: {
      isTransitioning = false
    }
  }

  private func finish() {
    guard !isTransitioning else { return }
    isTransitioning = true
    onFinish()
  }
}

#Preview("Reward sequence") {
  DeepSessionCompletionView(receipt: .sample)
}

#Preview("Reward sequence — later today") {
  DeepSessionCompletionView(receipt: .laterToday)
}

#Preview("Reward sequence — capped") {
  DeepSessionCompletionView(receipt: .capped)
}
