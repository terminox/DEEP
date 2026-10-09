import Testing
@testable import Deep

/// A Global Pause night folds two server-settled grants — attendance and a
/// first peace message — onto the snapshot taken when the meditation ended,
/// and reads the rhythm from the journal once the claim has settled.
@MainActor
struct GlobalPauseRewardReceiptTests {
  private let attendance = AwardGrant(hearts: 5, sunlight: 5, plantId: "oak")
  private let message = AwardGrant(hearts: 1, sunlight: 1, plantId: "oak")

  private func receipt(
    awards: [AwardGrant],
    before: GlobalPauseRewardSnapshot = .sample,
    continuity: ContinuityTransition = ContinuityTransition(before: 7, after: 7),
    continuityKnown: Bool = true,
    attendanceMissed: Bool = false,
    attendancePending: Bool = false
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
      heartsEarnedTodayAfter: before.heartsEarnedToday + hearts,
      continuity: continuity,
      continuityKnown: continuityKnown,
      attendanceMissed: attendanceMissed,
      attendancePending: attendancePending
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
    #expect(receipt.explainsMissedAttendance == false)
  }

  @Test("A pause as the day's first practice moves the rhythm on by one")
  func pauseAsFirstPracticeOfTheDay() {
    let receipt = receipt(
      awards: [attendance],
      continuity: ContinuityTransition(before: 7, after: 8)
    )

    #expect(receipt.continuityBefore == 7)
    #expect(receipt.continuityAfter == 8)
    #expect(receipt.returnedToday)
    #expect(receipt.showsContinuity)
  }

  @Test("A pause after an earlier practice today witnesses the rhythm")
  func pauseAfterAnEarlierPractice() {
    let receipt = receipt(awards: [attendance])

    #expect(receipt.continuityBefore == receipt.continuityAfter)
    #expect(receipt.returnedToday == false)
    #expect(receipt.showsContinuity)
  }

  @Test("A rhythm an earlier practice already witnessed rests")
  func continuityRestsWhenAlreadyWitnessed() {
    let receipt = receipt(awards: [attendance], before: .rhythmWitnessed)

    #expect(receipt.showsContinuity == false)
  }

  @Test("A journal never hydrated hides the beat rather than guess")
  func unknownContinuityRests() {
    let receipt = receipt(
      awards: [attendance],
      continuity: ContinuityTransition(before: 0, after: 1),
      continuityKnown: false
    )

    #expect(receipt.showsContinuity == false)
  }

  @Test("A missed night with no hearts explains why")
  func missedNightExplains() {
    let receipt = receipt(awards: [], attendanceMissed: true)

    #expect(receipt.attendanceMissed)
    #expect(receipt.explainsMissedAttendance)
  }

  @Test("An unanswered claim neither promises hearts nor calls the day full")
  func pendingClaimRests() {
    let receipt = receipt(
      awards: [],
      continuity: ContinuityTransition(before: 7, after: 7),
      attendancePending: true
    )

    #expect(receipt.awaitsAttendanceAward)
    #expect(receipt.explainsMissedAttendance == false)
    // Whether tonight keeps the day isn't known yet — the beat rests rather
    // than show N → N.
    #expect(receipt.continuityKnown == false)
    #expect(receipt.showsContinuity == false)
  }

  @Test("An unanswered claim beside a message heart shows the heart")
  func pendingClaimWithMessageAward() {
    let receipt = receipt(awards: [message], attendancePending: true)

    #expect(receipt.heartsAwarded == 1)
    #expect(receipt.awaitsAttendanceAward == false)
    #expect(receipt.showsContinuity == false)
  }

  @Test("An answered claim leaves the rhythm to the journal")
  func answeredClaimKeepsContinuity() {
    let receipt = receipt(awards: [attendance], continuity: ContinuityTransition(before: 7, after: 8))

    #expect(receipt.awaitsAttendanceAward == false)
    #expect(receipt.showsContinuity)
  }

  @Test("A missed night whose message still earned shows the heart, not the reason")
  func missedNightWithMessageAward() {
    let receipt = receipt(awards: [message], attendanceMissed: true)

    #expect(receipt.heartsAwarded == 1)
    #expect(receipt.explainsMissedAttendance == false)
  }
}
