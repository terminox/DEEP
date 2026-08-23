import Foundation
import Testing
@testable import Deep

/// The one day-stamp behind the continuity beat: it is spent once a day, it
/// survives a relaunch, and it lets go on its own when the day turns.
@MainActor
struct ContinuityWitnessTests {
  private func freshDefaults(_ suite: String) -> UserDefaults {
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
  }

  @Test("A day nobody has witnessed starts open")
  func startsUnwitnessed() {
    let witness = ContinuityWitness(defaults: freshDefaults("deep.continuity.test.fresh"))

    #expect(witness.hasWitnessedToday == false)
  }

  @Test("Witnessing spends today, and stays spent on re-read")
  func witnessingSpendsTheDay() {
    let suite = "deep.continuity.test.spent"
    let defaults = freshDefaults(suite)
    let witness = ContinuityWitness(defaults: defaults)

    witness.witnessToday()
    #expect(witness.hasWitnessedToday)

    // A relaunch reads the same stamp back.
    #expect(ContinuityWitness(defaults: defaults).hasWitnessedToday)
  }

  @Test("A witnessed day lets go once the day turns")
  func dayRollover() {
    let suite = "deep.continuity.test.rollover"
    let defaults = freshDefaults(suite)
    let today = Date(timeIntervalSince1970: 1_800_000_000)
    let tomorrow = today.addingTimeInterval(24 * 60 * 60)

    ContinuityWitness(defaults: defaults, now: { today }).witnessToday()

    #expect(ContinuityWitness(defaults: defaults, now: { today }).hasWitnessedToday)
    #expect(ContinuityWitness(defaults: defaults, now: { tomorrow }).hasWitnessedToday == false)
  }

  @Test("Signing out forgets the day, so the next account meets its own rhythm")
  func resetForgetsTheDay() {
    let defaults = freshDefaults("deep.continuity.test.reset")
    let witness = ContinuityWitness(defaults: defaults)

    witness.witnessToday()
    witness.resetLocalState()

    #expect(witness.hasWitnessedToday == false)
    #expect(ContinuityWitness(defaults: defaults).hasWitnessedToday == false)
  }
}
