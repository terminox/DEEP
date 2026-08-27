import SwiftUI

/// Conducts the rewarding end of a finished practice. The sequence only moves
/// forward: garden, compassion, then the once-daily continuity beat — shared
/// by every ending, with only the closing words changing between them.
struct RewardRitualView: View {
  private enum Step {
    case garden
    case compassion
    case continuity
  }

  let receipt: RewardReceipt
  /// How the continuity beat names the return. See `ContinuityRewardView`.
  var continuityHeadline = "You returned today"
  /// The label on the tap that ends the ritual.
  var finalButtonTitle = "Carry this calm"
  /// Whether the ritual paints its own atmosphere. False when an owner spans a
  /// longer ending and already holds one — two independently drifting
  /// atmospheres crossfading against each other visibly slide.
  var paintsBackground = true
  var onFinish: () -> Void = {}

  @Environment(\.continuityWitness) private var continuityWitness

  @State private var step = Step.garden
  @State private var isTransitioning = false

  var body: some View {
    ZStack {
      if paintsBackground {
        Color.moonCream.ignoresSafeArea()
        AtmosphereBackground()
      }

      switch step {
      case .garden:
        GardenRewardView(
          receipt: receipt,
          buttonTitle: "Continue",
          onContinue: showCompassion
        )
        .transition(.softDrift)

      case .compassion:
        if receipt.showsContinuity {
          CompassionRewardView(
            receipt: receipt,
            buttonTitle: "Continue",
            onContinue: showContinuity
          )
          .transition(.softDrift)
        } else {
          CompassionRewardView(
            receipt: receipt,
            buttonTitle: finalButtonTitle,
            isFinal: true,
            onContinue: finish
          )
          .transition(.softDrift)
        }

      case .continuity:
        ContinuityRewardView(
          receipt: receipt,
          headline: continuityHeadline,
          buttonTitle: finalButtonTitle,
          onFinish: finish
        )
        .transition(.softDrift)
      }
    }
  }

  private func showCompassion() {
    move(to: .compassion)
  }

  /// The day's one witnessing is spent here rather than when the receipt was
  /// composed, so an ending the member walks away from leaves the beat waiting
  /// for their next practice.
  private func showContinuity() {
    guard !isTransitioning else { return }
    continuityWitness.witnessToday()
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
  RewardRitualView(receipt: .sample)
    .environment(\.continuityWitness, .unwitnessed)
}

#Preview("Reward sequence — later today") {
  RewardRitualView(receipt: .laterToday)
    .environment(\.continuityWitness, .witnessed)
}

#Preview("Reward sequence — capped") {
  RewardRitualView(receipt: .capped)
    .environment(\.continuityWitness, .witnessed)
}

#Preview("Reward sequence — pause night") {
  RewardRitualView(
    receipt: .pauseNight,
    continuityHeadline: "Your rhythm continues"
  )
  .environment(\.continuityWitness, .unwitnessed)
}
