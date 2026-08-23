import Testing
@testable import Deep

/// The ending ritual's route and copy gates are derived from one frozen
/// receipt, independent of later store reconciliation.
@MainActor
struct DeepSessionRewardReceiptTests {
  @Test("The first completion today includes continuity")
  func firstCompletionIncludesContinuity() {
    #expect(DeepSessionRewardReceipt.sample.showsContinuity)
    #expect(DeepSessionRewardReceipt.sample.rewardsAreFull == false)
  }

  @Test("A later completion today ends after compassion")
  func laterCompletionOmitsContinuity() {
    #expect(DeepSessionRewardReceipt.laterToday.showsContinuity == false)
  }

  @Test("A capped session keeps a settled zero-reward receipt")
  func cappedReceipt() {
    let receipt = DeepSessionRewardReceipt.capped

    #expect(receipt.rewardsAreFull)
    #expect(receipt.gardenBefore == receipt.gardenAfter)
    #expect(receipt.heartBalanceBefore == receipt.heartBalanceAfter)
  }

  @Test("An unavailable garden is represented without inventing progress")
  func missingGarden() {
    let receipt = DeepSessionRewardReceipt.catchingUp

    #expect(receipt.gardenIsCatchingUp)
    #expect(receipt.gardenBefore == nil)
    #expect(receipt.gardenAfter == nil)
  }

  @Test("Crossing a plant threshold preserves both animation endpoints")
  func evolutionEndpoints() {
    let receipt = DeepSessionRewardReceipt.evolving

    #expect(receipt.gardenBefore?.stageIndex == 0)
    #expect(receipt.gardenAfter?.stageIndex == 1)
    #expect(receipt.sunlightAwarded == 1)
  }
}

