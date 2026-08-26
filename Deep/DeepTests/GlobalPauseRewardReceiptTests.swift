import Testing
@testable import Deep

/// A Global Pause night folds two server-settled grants — attendance and a
/// first peace message — onto the snapshot taken when the meditation ended.
@MainActor
struct GlobalPauseRewardReceiptTests {
  private let attendance = AwardGrant(hearts: 5, sunlight: 5, plantId: "oak")
  private let message = AwardGrant(hearts: 1, sunlight: 1, plantId: "oak")

  private func receipt(
    awards: [AwardGrant],
    before: GlobalPauseRewardSnapshot = .sample
  ) -> RewardReceipt {
    let hearts = awards.reduce(0) { $0 + $1.hearts }
    let sunlight = awards.reduce(0) { $0 + $1.sunlight }
    return RewardReceipt(
      pauseNight: before,
      awards: awards,
      gardenAfter: before.garden.map {
        GardenGrowth(plant: $0.plant, sunlight: $0.sunlight + sunlight)
      },
      heartBalanceAfter: before.heartBalance + hearts,
      heartsEarnedTodayAfter: before.heartsEarnedToday + hearts
    )
  }

  @Test("Attending alone is worth the night's five")
  func attendanceOnly() {
    let receipt = receipt(awards: [attendance])

    #expect(receipt.heartsAwarded == 5)
    #expect(receipt.sunlightAwarded == 5)
    #expect(receipt.heartBalanceAfter == 17)
  }

  @Test("A peace message adds to the same total")
  func attendanceAndMessage() {
    let receipt = receipt(awards: [attendance, message])

    #expect(receipt.heartsAwarded == 6)
    #expect(receipt.sunlightAwarded == 6)
    #expect(receipt.gardenAfter?.sunlight == 246)
  }

  @Test("A night that earned nothing settles rather than promises")
  func ineligibleNight() {
    let receipt = receipt(awards: [])

    #expect(receipt.rewardsAreFull)
    #expect(receipt.gardenBefore == receipt.gardenAfter)
    #expect(receipt.heartBalanceBefore == receipt.heartBalanceAfter)
  }

  @Test("The rhythm is witnessed, never moved by a pause")
  func continuityIsWitnessed() {
    let receipt = receipt(awards: [attendance])

    #expect(receipt.continuityBefore == receipt.continuityAfter)
    #expect(receipt.showsContinuity)
  }

  @Test("A rhythm an earlier practice already witnessed rests")
  func continuityRestsWhenAlreadyWitnessed() {
    let receipt = receipt(awards: [attendance], before: .rhythmWitnessed)

    #expect(receipt.showsContinuity == false)
  }
}
