import Testing
import Foundation
@testable import Deep

/// The pause-award lifecycle around the reflection screen. The regression this
/// guards: `leaveSession()` runs mid-reflection (the handback releases presence
/// while the ending ritual — the award's one reader — is still up), so clearing
/// the award there, or cancelling a claim still in flight, meant the night's
/// hearts never showed even though the server had granted them.
@MainActor
struct GlobalPauseAwardTests {
  private func makeSession(
    rewards: MockRewardsRemote,
    awardSink: (@MainActor (AwardGrant) -> Void)? = nil
  ) -> GlobalPauseSession {
    GlobalPauseSession(
      clock: SyncedClock(),
      repository: FixturePauseEventRepository(),
      rewards: rewards,
      awardSink: awardSink
    )
  }

  /// Polls until the async claim settles (bounded, so a broken claim fails the
  /// test rather than hanging it).
  private func settledAward(of session: GlobalPauseSession) async throws -> AwardGrant {
    for _ in 0..<200 where session.pauseAward == nil {
      try await Task.sleep(for: .milliseconds(10))
    }
    return try #require(session.pauseAward)
  }

  @Test("A settled claim survives the reflection handback's leaveSession")
  func awardSurvivesLeaveSession() async throws {
    let rewards = MockRewardsRemote()
    var sunk: [AwardGrant] = []
    let session = makeSession(rewards: rewards) { sunk.append($0) }

    session.enterSession()
    session.claimPauseAward()
    let award = try await settledAward(of: session)

    #expect(award.hearts == 5)
    #expect(award.sunlight == 5)
    #expect(sunk.count == 1)

    // The handback releases presence while the reflection screen is still up —
    // the caption it renders must keep its award.
    session.leaveSession()
    #expect(session.pauseAward != nil)
  }

  @Test("The next session visit starts without last night's award")
  func nextVisitStartsClean() async throws {
    let rewards = MockRewardsRemote()
    let session = makeSession(rewards: rewards)

    session.enterSession()
    session.claimPauseAward()
    _ = try await settledAward(of: session)
    session.leaveSession()

    session.enterSession()
    #expect(session.pauseAward == nil)
    session.leaveSession()
  }

  @Test("A claim landing after leaveSession still reaches the caption and sink")
  func lateClaimStillLands() async throws {
    let rewards = MockRewardsRemote()
    var sunk: [AwardGrant] = []
    let session = makeSession(rewards: rewards) { sunk.append($0) }

    session.enterSession()
    session.claimPauseAward()
    // Leave immediately — the claim is still in flight, exactly the timing of
    // a fast reflection crossfade over a slow network.
    session.leaveSession()

    let award = try await settledAward(of: session)
    #expect(award.hearts == 5)
    #expect(sunk.count == 1)
  }

  @Test("Waiting for a claim returns once it settles")
  func settleWaitsForTheClaim() async throws {
    let session = makeSession(rewards: MockRewardsRemote())

    session.enterSession()
    session.claimPauseAward()
    await session.settlePauseAward()

    // The ritual composes straight after this call, so the grant must be here.
    #expect(session.pauseAward?.hearts == 5)
    session.leaveSession()
  }

  @Test("Waiting when nothing is in flight returns at once")
  func settleReturnsWithoutAClaim() async throws {
    let session = makeSession(rewards: MockRewardsRemote())

    await session.settlePauseAward()

    #expect(session.pauseAward == nil)
  }

  @Test("The night's first peace message is kept for the ritual's total")
  func firstMessageAwardIsKept() async throws {
    let session = makeSession(rewards: MockRewardsRemote())
    session.enterSession()

    _ = try await session.post(message: "Peace to you all", intention: "peace")
    #expect(session.messageAward?.hearts == 1)
    #expect(session.messageAward?.sunlight == 1)

    // Later messages come back bare — the first award stays the night's truth.
    _ = try await session.post(message: "And again", intention: nil)
    #expect(session.messageAward?.hearts == 1)
    session.leaveSession()
  }

  @Test("The next session visit starts without last night's message award")
  func nextVisitForgetsTheMessageAward() async throws {
    let session = makeSession(rewards: MockRewardsRemote())
    session.enterSession()
    _ = try await session.post(message: "Peace to you all", intention: "peace")
    #expect(session.messageAward != nil)
    session.leaveSession()

    session.enterSession()
    #expect(session.messageAward == nil)
    session.leaveSession()
  }
}
