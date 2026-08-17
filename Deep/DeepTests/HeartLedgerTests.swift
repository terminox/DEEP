import Testing
import Foundation
@testable import Deep

/// The daily earn ceiling — the one piece of ledger behaviour that can't be
/// reached by hand (it takes thirty finished sessions), so it's pinned here.
@MainActor
struct HeartLedgerTests {
  private var ceiling: Int { HeartLedger.dailyEarnCeiling }

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

  @Test("Giving a heart spends the balance without touching today's tally")
  func givingLeavesTodayAlone() {
    let ledger = HeartLedger(balance: 5, heartsEarnedToday: 3)
    let cause = ledger.categories[0]

    ledger.sendHeart(to: cause)

    #expect(ledger.balance == 4)
    #expect(ledger.heartsGiven == 1)
    #expect(ledger.heartsEarnedToday == 3)
  }

  @Test("The spent fixture is a full day with nothing left to give")
  func spentFixture() {
    let ledger = HeartLedger.spent

    #expect(ledger.canGive == false)
    #expect(ledger.isTodayFull)
  }
}
