import Testing
import Foundation
@testable import Deep

/// The ledger's three behaviours that can't be reached by hand: the daily earn
/// ceiling (thirty finished sessions), the absolute reconcile that keeps
/// optimistic credits from double-counting, and the spend rollback when the
/// server refuses.
@MainActor
struct HeartLedgerTests {
  private var ceiling: Int { HeartLedger.dailyEarnCeiling }

  // MARK: - The earn predictor

  @Test("A fresh day starts empty and open")
  func freshDay() {
    let ledger = HeartLedger(balance: 0)

    #expect(ledger.heartsEarnedToday == 0)
    #expect(ledger.heartsRemainingToday == ceiling)
    #expect(ledger.isTodayFull == false)
  }

  @Test("Earning credits the balance and today's tally together")
  func earnCredits() {
    let ledger = HeartLedger(balance: 10)

    #expect(ledger.earn() == 1)
    #expect(ledger.balance == 11)
    #expect(ledger.heartsEarnedToday == 1)
    #expect(ledger.heartsRemainingToday == ceiling - 1)
  }

  @Test("A day fills at the ceiling and no further")
  func fillsToCeiling() {
    let ledger = HeartLedger(balance: 0)

    for _ in 0..<ceiling {
      _ = ledger.earn()
    }

    #expect(ledger.balance == ceiling)
    #expect(ledger.heartsEarnedToday == ceiling)
    #expect(ledger.isTodayFull)

    // The session past the ceiling still counts as practice, but hands over no
    // heart — the completion beat reads this to decide what it promises.
    #expect(ledger.earn() == 0)
    #expect(ledger.balance == ceiling)
    #expect(ledger.heartsEarnedToday == ceiling)
  }

  @Test("A batch earn is clamped to what the day has left")
  func batchIsClamped() {
    let ledger = HeartLedger(balance: 0, heartsEarnedToday: ceiling - 2)

    #expect(ledger.earn(5) == 2)
    #expect(ledger.balance == 2)
    #expect(ledger.isTodayFull)
  }

  @Test("A tally passed in above the ceiling is clamped, never negative remaining")
  func initClampsTally() {
    let ledger = HeartLedger(balance: 0, heartsEarnedToday: ceiling + 40)

    #expect(ledger.heartsEarnedToday == ceiling)
    #expect(ledger.heartsRemainingToday == 0)
  }

  // MARK: - Hydration & absolute reconcile

  @Test("Hydrating adopts the server's absolute wallet figures")
  func hydrateSetsAbsolutes() {
    let ledger = HeartLedger(balance: 0)

    ledger.hydrate(HeartsSummary(
      balance: 42,
      earned: 60,
      given: 18,
      earnedToday: 3,
      remainingToday: 27,
      dailyCap: 30,
      givenByCategory: ["peace": 18]
    ))

    #expect(ledger.balance == 42)
    #expect(ledger.heartsGiven == 18)
    #expect(ledger.heartsEarnedToday == 3)
    #expect(ledger.heartsRemainingToday == ceiling - 3)
    #expect(ledger.heartsGiven(in: "peace") == 18)
  }

  @Test("Applying a grant with absolutes reconciles an optimistic earn, never doubles it")
  func applyReconcilesAbsolutes() {
    let ledger = HeartLedger(balance: 10)
    _ = ledger.earn() // Optimistic +1 the completion beat already played.

    // The practice sync answers with the same award as absolute figures.
    ledger.apply(AwardGrant(
      hearts: 1,
      sunlight: 1,
      plantId: "oak",
      heartsBalance: 11,
      heartsEarnedToday: 1
    ))

    #expect(ledger.balance == 11)
    #expect(ledger.heartsEarnedToday == 1)
  }

  @Test("A grant without snapshots falls back to its deltas")
  func applyDeltaFallback() {
    let ledger = HeartLedger(balance: 10, heartsEarnedToday: 2)

    ledger.apply(AwardGrant(hearts: 5, sunlight: 5, plantId: "oak"))

    #expect(ledger.balance == 15)
    #expect(ledger.heartsEarnedToday == 7)
  }

  // MARK: - Giving

  @Test("Giving a heart spends the balance without touching today's tally")
  func givingLeavesTodayAlone() {
    let ledger = HeartLedger(balance: 5, heartsEarnedToday: 3)
    let cause = ledger.categories[0]

    ledger.sendHeart(to: cause)

    #expect(ledger.balance == 4)
    #expect(ledger.heartsGiven == 1)
    #expect(ledger.heartsEarnedToday == 3)
  }

  @Test("A remote-backed send is optimistic, then settles on the server's absolutes")
  func sendReconcilesWithServer() async {
    let remote = MockRewardsRemote(wallet: HeartsSummary(
      balance: 5, earned: 5, given: 0, earnedToday: 0,
      remainingToday: 30, dailyCap: 30, givenByCategory: [:]
    ))
    let ledger = HeartLedger(balance: 5, remote: remote)
    let cause = ledger.categories[0]

    ledger.send(2, to: cause)
    #expect(ledger.balance == 3) // Optimistic, before the POST lands.

    await ledger.pendingSpend?.value
    #expect(ledger.balance == 3)
    #expect(ledger.heartsGiven == 2)
    #expect(ledger.spendFailure == nil)
    #expect(remote.spends.count == 1)
    #expect(remote.spends.first?.amount == 2)
    #expect(remote.spends.first?.category == cause.id)
  }

  @Test("A refused spend rolls the whole optimistic mutation back")
  func sendRollsBackOnServerRefusal() async {
    let remote = MockRewardsRemote()
    remote.failsSpend = true
    let ledger = HeartLedger(balance: 5, remote: remote)
    let cause = ledger.categories[0]
    let pooledBefore = cause.heartsShared

    ledger.send(2, to: cause)
    #expect(ledger.balance == 3) // Optimistic decrement plays immediately.

    await ledger.pendingSpend?.value
    #expect(ledger.balance == 5)
    #expect(ledger.heartsGiven == 0)
    #expect(ledger.heartsGiven(in: cause.id) == 0)
    #expect(ledger.category(cause.id)?.heartsShared == pooledBefore)
    #expect(ledger.spendFailure == HeartLedger.SpendFailure(amount: 2, categoryID: cause.id))
  }

  @Test("Without a remote, sends stay purely local — the fixture behaviour")
  func sendWithoutRemoteStaysLocal() async {
    let ledger = HeartLedger(balance: 5)
    let cause = ledger.categories[0]

    ledger.send(2, to: cause)

    #expect(ledger.pendingSpend == nil)
    #expect(ledger.balance == 3)
    #expect(ledger.heartsGiven == 2)
  }

  @Test("The spent fixture is a full day with nothing left to give")
  func spentFixture() {
    let ledger = HeartLedger.spent

    #expect(ledger.canGive == false)
    #expect(ledger.isTodayFull)
  }
}
