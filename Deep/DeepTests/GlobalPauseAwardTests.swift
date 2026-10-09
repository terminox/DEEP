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
    awardSink: (@MainActor (AwardGrant) -> Void)? = nil,
    activitySink: (@MainActor (Date) -> Void)? = nil
  ) -> GlobalPauseSession {
    GlobalPauseSession(
      clock: SyncedClock(),
      repository: FixturePauseEventRepository(),
      rewards: rewards,
      awardSink: awardSink,
      activitySink: activitySink,
      // The real backoff, compressed — same shape, no multi-second waits.
      claimRetryDelays: [.zero, .milliseconds(10), .milliseconds(20), .milliseconds(40)]
    )
  }

  /// Polls until the claim has finished, whatever it resolved to.
  private func settled(_ session: GlobalPauseSession) async {
    await session.settlePauseAward(timeout: .seconds(2))
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

  // MARK: - Claim retries

  @Test("A claim lost to the network is retried until it lands")
  func transportFailuresRetryThenLand() async throws {
    let rewards = MockRewardsRemote()
    rewards.pauseClaimFailures = 2
    var sunk: [AwardGrant] = []
    let session = makeSession(rewards: rewards) { sunk.append($0) }

    session.enterSession()
    session.claimPauseAward()
    let award = try await settledAward(of: session)

    #expect(award.hearts == 5)
    #expect(rewards.pauseClaimAttempts == 3)
    #expect(sunk.count == 1)
    session.leaveSession()
  }

  @Test("The retry gives up after its last attempt")
  func retryIsBounded() async {
    let rewards = MockRewardsRemote()
    rewards.pauseClaimFailures = 10
    let session = makeSession(rewards: rewards)

    session.enterSession()
    session.claimPauseAward()
    await settled(session)

    #expect(rewards.pauseClaimAttempts == 4)
    #expect(session.pauseAward == nil)
    #expect(session.pauseAwardMissed == false)
    // No answer ever came: the night's outcome is unknown, not "full".
    #expect(session.pauseAwardPending)
    session.leaveSession()

    session.enterSession()
    #expect(session.pauseAwardPending == false)
    session.leaveSession()
  }

  @Test("A claim still unanswered when the ending composes is pending, then lands")
  func slowClaimIsPendingThenLands() async throws {
    let rewards = MockRewardsRemote()
    rewards.pauseClaimDelay = .milliseconds(400)
    var sunk: [AwardGrant] = []
    let session = makeSession(rewards: rewards) { sunk.append($0) }

    session.enterSession()
    session.claimPauseAward()
    // The ending's wait runs out first — the regression: this used to read
    // as no award and not missed, i.e. "Today is full".
    await session.settlePauseAward(timeout: .milliseconds(50))
    #expect(session.pauseAwardPending)
    #expect(session.pauseAward == nil)
    #expect(session.pauseAwardMissed == false)

    // The late answer still lands, and reconciles the stores.
    let award = try await settledAward(of: session)
    #expect(award.hearts == 5)
    #expect(session.pauseAwardPending == false)
    #expect(sunk.count == 1)
    session.leaveSession()
  }

  @Test("An answered claim is never pending")
  func answeredClaimIsNotPending() async {
    let rewards = MockRewardsRemote()
    rewards.pauseEligible = false
    let session = makeSession(rewards: rewards)

    session.enterSession()
    session.claimPauseAward()
    #expect(session.pauseAwardPending)
    await settled(session)

    #expect(session.pauseAwardPending == false)
    #expect(session.pauseAwardMissed)
    session.leaveSession()
  }

  @Test("An expired session is an answer, not a blip — no retry")
  func unauthorizedIsNotRetried() async {
    let rewards = MockRewardsRemote()
    rewards.pauseClaimFailures = 1
    rewards.pauseClaimError = .unauthorized
    let session = makeSession(rewards: rewards)

    session.enterSession()
    session.claimPauseAward()
    await settled(session)

    #expect(rewards.pauseClaimAttempts == 1)
    #expect(session.pauseAward == nil)
    session.leaveSession()
  }

  // MARK: - Eligibility

  @Test("An ineligible night is marked missed and keeps no day")
  func ineligibleNightIsMissed() async {
    let rewards = MockRewardsRemote()
    rewards.pauseEligible = false
    var sunk: [AwardGrant] = []
    var days: [Date] = []
    let session = makeSession(
      rewards: rewards,
      awardSink: { sunk.append($0) },
      activitySink: { days.append($0) }
    )

    session.enterSession()
    session.claimPauseAward()
    await settled(session)

    #expect(session.pauseAwardMissed)
    #expect(session.pauseAward == nil)
    #expect(sunk.isEmpty)
    #expect(days.isEmpty)

    // Like the award, it survives the reflection handback…
    session.leaveSession()
    #expect(session.pauseAwardMissed)

    // …and is forgotten as the next visit begins.
    session.enterSession()
    #expect(session.pauseAwardMissed == false)
    session.leaveSession()
  }

  @Test("A counted night keeps the day in the rhythm")
  func eligibleNightRecordsActivity() async throws {
    var days: [Date] = []
    let session = makeSession(rewards: MockRewardsRemote(), activitySink: { days.append($0) })

    session.enterSession()
    session.claimPauseAward()
    _ = try await settledAward(of: session)

    #expect(days.count == 1)
    #expect(session.pauseAwardMissed == false)
    session.leaveSession()
  }

  @Test("A night already claimed still counts, with no fresh grant")
  func alreadyClaimedNightStillCounts() async throws {
    let rewards = MockRewardsRemote()
    var days: [Date] = []
    let session = makeSession(rewards: rewards, activitySink: { days.append($0) })

    session.enterSession()
    session.claimPauseAward()
    _ = try await settledAward(of: session)
    session.leaveSession()

    // A second visit the same night: the server has nothing more to give.
    session.enterSession()
    session.claimPauseAward()
    await settled(session)

    #expect(session.pauseAward == nil)
    #expect(session.pauseAwardMissed == false)
    #expect(days.count == 2)
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
