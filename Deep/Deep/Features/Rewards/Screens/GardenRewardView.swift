import SwiftUI

/// The first reward: the member's chosen plant receives this session's
/// sunlight. It borrows the garden's portrait halo, stripped to one calm fact.
struct GardenRewardView: View {
  let receipt: RewardReceipt
  let buttonTitle: String
  /// Whether this step closes the ritual — the button reads its hint from this.
  let isFinal: Bool
  let onContinue: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var displayedGrowth: GardenGrowth?
  @State private var displayedProgress: Double
  @State private var displayedSunlight: Int
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
    let initial = receipt.gardenBefore ?? receipt.gardenAfter
    _displayedGrowth = State(initialValue: initial)
    _displayedProgress = State(initialValue: initial?.evolutionProgress ?? 0)
    _displayedSunlight = State(initialValue: initial?.sunlight ?? 0)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: .rhythm * 1.5) {
        VStack(spacing: 7) {
          Text("MIND GARDEN")
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(.driftGrey)
          Text(title)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
            .multilineTextAlignment(.center)
        }

        gardenCard
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

  private var title: String {
    if receipt.gardenIsCatchingUp {
      return String(localized: "Growth is on its way", bundle: .app, locale: .app)
    }
    if receipt.sunlightAwarded > 0 {
      return String(localized: "Your garden grew", bundle: .app, locale: .app)
    }
    // A pause night the server didn't count — or hasn't answered for yet —
    // thank the member for the pause they did take rather than call the
    // garden resting (see `rewardLine`).
    if receipt.explainsMissedAttendance || receipt.awaitsAttendanceAward {
      return String(localized: "Thank you for pausing", bundle: .app, locale: .app)
    }
    return String(localized: "Your garden is resting", bundle: .app, locale: .app)
  }

  private var gardenCard: some View {
    VStack(spacing: 18) {
      if let displayedGrowth {
        ZStack {
          PlantGrowthHalo(
            stage: displayedGrowth.stage,
            palette: displayedGrowth.plant.palette,
            progress: displayedProgress,
            portraitDiameter: 126,
            ringGap: 7,
            ringWidth: 5
          )
          .id(displayedGrowth.stage.id)
          .transition(.opacity.combined(with: .scale(scale: 0.94)))
        }

        VStack(spacing: 7) {
          Text(displayedGrowth.stage.name)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
            .contentTransition(.opacity)

          // Absent while the night's award is still on its way.
          if let rewardLine {
            Text(rewardLine)
              .font(DeepType.body.weight(.semibold))
              .foregroundStyle(receipt.sunlightAwarded > 0 ? GardenColor.sunbeam : .driftGrey)
              .multilineTextAlignment(.center)
          }

          Text(progressLine(for: displayedGrowth))
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .contentTransition(.numericText(value: Double(displayedSunlight)))
            .monospacedDigit()
        }
      } else {
        catchingUpArtwork
        VStack(spacing: 7) {
          Text("Your garden is catching up")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          Text("Your practice is safely remembered")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 28)
    .padding(.horizontal, 20)
    .frostedCard(tint: GardenColor.sage)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
  }

  private var catchingUpArtwork: some View {
    ZStack {
      Circle()
        .stroke(GardenColor.meadow.opacity(0.55), lineWidth: 5)
      Circle()
        .fill(.white.opacity(0.62))
        .padding(12)
      Image(systemName: "sun.max.fill")
        .font(.system(size: 44, weight: .light))
        .foregroundStyle(GardenColor.sunbeam)
    }
    .frame(width: 150, height: 150)
    .accessibilityHidden(true)
  }

  /// The line under the stage name; nil while the night's award is unknown.
  private var rewardLine: String? {
    if receipt.sunlightAwarded > 0 {
      return String(localized: "+\(receipt.sunlightAwarded) sunlight", bundle: .app, locale: .app)
    }
    if receipt.explainsMissedAttendance {
      return String(localized: "Stay through the meditation to receive hearts", bundle: .app, locale: .app)
    }
    if receipt.awaitsAttendanceAward { return nil }
    return String(localized: "Today is full", bundle: .app, locale: .app)
  }

  private func progressLine(for growth: GardenGrowth) -> String {
    let sunlight = displayedSunlight.formatted(.number.locale(.app))
    guard let next = growth.nextStage,
          let goal = growth.sunlightToEvolve
    else {
      return String(localized: "\(sunlight) sunlight, fully grown", bundle: .app, locale: .app)
    }
    let target = goal.formatted(.number.locale(.app))
    return String(localized: "\(sunlight) of \(target) to \(next.name)", bundle: .app, locale: .app)
  }

  private var accessibilitySummary: String {
    guard let growth = receipt.gardenAfter else {
      let catchingUp = String(localized: "Your garden is catching up", bundle: .app, locale: .app)
      let remembered = String(localized: "Your practice is safely remembered", bundle: .app, locale: .app)
      return "\(catchingUp). \(remembered)."
    }
    if receipt.sunlightAwarded > 0 {
      let received = String(
        localized: "\(receipt.sunlightAwarded) sunlight received",
        bundle: .app,
        locale: .app
      )
      return "\(growth.stage.name). \(received)."
    }
    if let rewardLine {
      return "\(growth.stage.name). \(rewardLine)."
    }
    return "\(growth.stage.name). \(title)."
  }

  private func playEntrance() async {
    if reduceMotion {
      settleImmediately()
      hasArrived = true
    } else {
      withAnimation(.bloom) { hasArrived = true }
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      animateReward()
    }
    AccessibilityNotification.Announcement(accessibilitySummary).post()
  }

  private func settleImmediately() {
    displayedGrowth = receipt.gardenAfter ?? receipt.gardenBefore
    displayedProgress = displayedGrowth?.evolutionProgress ?? 0
    displayedSunlight = displayedGrowth?.sunlight ?? 0
  }

  private func animateReward() {
    guard receipt.sunlightAwarded > 0,
          let before = receipt.gardenBefore,
          let after = receipt.gardenAfter
    else {
      settleImmediately()
      return
    }

    if before.stageIndex != after.stageIndex {
      withAnimation(.exhale) {
        displayedSunlight = after.sunlight
        displayedProgress = 1
      } completion: {
        withAnimation(.bloom) {
          displayedGrowth = after
          displayedProgress = after.evolutionProgress
        }
      }
    } else {
      withAnimation(.exhale) {
        displayedGrowth = after
        displayedSunlight = after.sunlight
        displayedProgress = after.evolutionProgress
      }
    }
  }
}

#Preview("Garden reward") {
  GardenRewardView(receipt: .sample, buttonTitle: "Continue", onContinue: {})
}

#Preview("Garden reward — evolution") {
  GardenRewardView(receipt: .evolving, buttonTitle: "Continue", onContinue: {})
}

#Preview("Garden reward — capped") {
  GardenRewardView(receipt: .capped, buttonTitle: "Continue", onContinue: {})
}

#Preview("Garden reward — catching up") {
  GardenRewardView(receipt: .catchingUp, buttonTitle: "Continue", onContinue: {})
}

#Preview("Garden reward — large type") {
  GardenRewardView(receipt: .sample, buttonTitle: "Continue", onContinue: {})
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Garden reward — pause night") {
  GardenRewardView(receipt: .pauseNight, buttonTitle: "Continue", onContinue: {})
}

#Preview("Garden reward — pause claim on its way") {
  GardenRewardView(receipt: .pausePending, buttonTitle: "Continue", onContinue: {})
}

#Preview("Garden reward — pause missed") {
  GardenRewardView(receipt: .pauseMissed, buttonTitle: "Continue", onContinue: {})
}
