import Testing
@testable import Deep

/// The ending ritual's route and copy gates are derived from one frozen
/// receipt, independent of later store reconciliation.
@MainActor
struct RewardReceiptTests {
  @Test("An unwitnessed day includes continuity")
  func unwitnessedDayIncludesContinuity() {
    #expect(RewardReceipt.sample.showsContinuity)
    #expect(RewardReceipt.sample.rewardsAreFull == false)
  }

  @Test("A day already witnessed ends after compassion")
  func witnessedDayOmitsContinuity() {
    #expect(RewardReceipt.laterToday.showsContinuity == false)
  }

  @Test("A rhythm of no days is never shown")
  func emptyRhythmOmitsContinuity() {
    let receipt = RewardReceipt(
      gardenBefore: nil,
      gardenAfter: nil,
      sunlightAwarded: 0,
      heartBalanceBefore: 0,
      heartBalanceAfter: 0,
      heartsEarnedTodayBefore: 0,
      heartsEarnedTodayAfter: 0,
      heartsAwarded: 0,
      continuityBefore: 0,
      continuityAfter: 0,
      continuityWitnessedToday: false
    )

    #expect(receipt.showsContinuity == false)
  }

  @Test("A capped session keeps a settled zero-reward receipt")
  func cappedReceipt() {
    let receipt = RewardReceipt.capped

    #expect(receipt.rewardsAreFull)
    #expect(receipt.gardenBefore == receipt.gardenAfter)
    #expect(receipt.heartBalanceBefore == receipt.heartBalanceAfter)
  }

  @Test("An unavailable garden is represented without inventing progress")
  func missingGarden() {
    let receipt = RewardReceipt.catchingUp

    #expect(receipt.gardenIsCatchingUp)
    #expect(receipt.gardenBefore == nil)
    #expect(receipt.gardenAfter == nil)
  }

  @Test("Crossing a plant threshold preserves both animation endpoints")
  func evolutionEndpoints() {
    let receipt = RewardReceipt.evolving

    #expect(receipt.gardenBefore?.stageIndex == 0)
    #expect(receipt.gardenAfter?.stageIndex == 1)
    #expect(receipt.sunlightAwarded == 1)
  }

  @Test("A pause night witnesses the rhythm without moving it")
  func pauseNightWitnessesRhythm() {
    let receipt = RewardReceipt.pauseNight

    #expect(receipt.showsContinuity)
    #expect(receipt.continuityBefore == receipt.continuityAfter)
    #expect(receipt.heartsAwarded == 6)
    #expect(receipt.sunlightAwarded == 6)
  }

  @Test("New flags default to a known rhythm and an attended night")
  func flagsDefault() {
    #expect(RewardReceipt.sample.continuityKnown)
    #expect(RewardReceipt.sample.attendanceMissed == false)
    #expect(RewardReceipt.sample.explainsMissedAttendance == false)
  }

  @Test("An unknown rhythm hides the beat on an otherwise unwitnessed day")
  func unknownContinuityHidesTheBeat() {
    let receipt = RewardReceipt(
      gardenBefore: nil,
      gardenAfter: nil,
      sunlightAwarded: 0,
      heartBalanceBefore: 2,
      heartBalanceAfter: 3,
      heartsEarnedTodayBefore: 0,
      heartsEarnedTodayAfter: 1,
      heartsAwarded: 1,
      continuityBefore: 0,
      continuityAfter: 1,
      continuityWitnessedToday: false,
      continuityKnown: false
    )

    #expect(receipt.showsContinuity == false)
  }

  @Test("The missed-pause fixture explains its empty night")
  func pauseMissedExplains() {
    #expect(RewardReceipt.pauseMissed.explainsMissedAttendance)
    #expect(RewardReceipt.pauseReturn.returnedToday)
  }
}
