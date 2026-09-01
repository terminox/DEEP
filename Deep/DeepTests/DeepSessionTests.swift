import Testing
import Foundation
@testable import Deep

/// The mapping between a length chosen in minutes and the rounds the engine
/// actually runs. At the shipped 4s in / 6s out pattern a round is exactly ten
/// seconds, so every offered minute lands on whole rounds with nothing over.
@MainActor
struct DeepSessionTests {
  private static func fixture() -> DeepSession {
    DeepSession(title: "Balancing breath", tagline: "", cycles: 6)
  }

  @Test
  func shortestLengthIsSixRounds() {
    #expect(Self.fixture().lasting(minutes: 1).cycles == 6)
  }

  @Test
  func longestLengthIsSixtyRounds() {
    #expect(Self.fixture().lasting(minutes: 10).cycles == 60)
  }

  /// Re-lengthing yields the same practice, only longer — the id included, so
  /// the presenter carrying it into the run isn't handed a new identity on
  /// every render.
  @Test
  func lengtheningKeepsTheSamePractice() {
    let session = Self.fixture()
    let longer = session.lasting(minutes: 7)

    #expect(longer.id == session.id)
    #expect(longer.title == session.title)
    #expect(longer.tagline == session.tagline)
    #expect(longer.inhale == session.inhale)
    #expect(longer.exhale == session.exhale)
  }

  /// The invariant that keeps what the app promises and what it credits in
  /// agreement: `durationMinutes` rounds up while the practice journal floors
  /// its seconds, and the two only agree on exact multiples of sixty.
  @Test
  func everyOfferedLengthIsAWholeNumberOfMinutes() {
    for minutes in DeepSessionLength.range {
      let session = Self.fixture().lasting(minutes: minutes)
      #expect(session.duration == TimeInterval(minutes) * 60)
      #expect(session.durationMinutes == minutes)
    }
  }

  @Test
  func neverShorterThanOneRound() {
    #expect(Self.fixture().lasting(minutes: 0).cycles == 1)
  }
}
