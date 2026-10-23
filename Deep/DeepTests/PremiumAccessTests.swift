import Testing
import Foundation
@testable import Deep

/// The reconciliation between the store's answer and the server's: the union
/// grants, a purchase unlocks at once and is confirmed on a ladder, the flip
/// counter moves once per flip, and nothing regresses to locked offline.
@MainActor
struct PremiumAccessTests {
  /// A fresh `UserDefaults` suite per test, so remembered answers never leak.
  private static func makeDefaults() -> UserDefaults {
    let name = "DeepTests-premium-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
  }

  /// A clock the test moves by hand.
  private final class Clock {
    var now = Date(timeIntervalSince1970: 1_000_000)
  }

  private static func access(
    store: SubscriptionState = .none,
    fetcher: MockEntitlementFetcher? = nil,
    defaults: UserDefaults? = nil,
    clock: Clock? = nil
  ) -> PremiumAccess {
    let clock = clock ?? Clock()
    return PremiumAccess(
      store: MockSubscriptionStore(status: store),
      fetcher: fetcher,
      defaults: defaults ?? makeDefaults(),
      now: { clock.now },
      // Tests never wait: every rung of the ladder is instant.
      sleep: { _ in },
      confirmationDelays: [.zero, .zero, .zero]
    )
  }

  // MARK: - Truth table

  @Test("Server no, store yes: unlocked")
  func serverNoStoreYes() {
    let access = Self.access(store: .subscribed(productID: DeepProduct.yearly))
    access.adopt(.lapsed)
    #expect(access.hasPremium)
  }

  @Test("Server yes, store no: unlocked")
  func serverYesStoreNo() {
    let access = Self.access(store: .none)
    access.adopt(.member)
    #expect(access.hasPremium)
  }

  @Test("Both no: locked")
  func bothNo() {
    let access = Self.access(store: .none)
    access.adopt(.lapsed)
    #expect(!access.hasPremium)
  }

  @Test("Both unknown: locked")
  func bothUnknown() {
    let access = Self.access(store: .unknown)
    #expect(access.server == nil)
    #expect(!access.hasPremium)
  }

  @Test("Store still checking, server last said yes: unlocked from launch")
  func rememberedServerCarriesUnknownStore() {
    let defaults = Self.makeDefaults()
    let first = Self.access(store: .none, defaults: defaults)
    first.identify(userID: "u1")
    first.adopt(.member)

    let relaunched = Self.access(store: .unknown, defaults: defaults)
    #expect(relaunched.server == true)
    #expect(relaunched.hasPremium)
  }

  @Test("An older server that sends no entitlement changes nothing")
  func olderServerSilent() {
    let access = Self.access(store: .subscribed(productID: DeepProduct.monthly))
    access.adopt(nil)
    #expect(access.server == nil)
    #expect(access.hasPremium)
    #expect(access.flipCount == 0)
  }

  // MARK: - Offline

  @Test("Server unreachable: the store's cached yes stands")
  func offlineFallsBackToStore() async {
    let fetcher = MockEntitlementFetcher(answers: [.failure(.init())])
    let access = Self.access(store: .subscribed(productID: DeepProduct.yearly), fetcher: fetcher)
    await access.refresh()
    #expect(fetcher.currentCalls == 1)
    #expect(access.hasPremium)
  }

  @Test("Server unreachable: a remembered yes never regresses to locked")
  func offlineKeepsRememberedYes() async {
    let defaults = Self.makeDefaults()
    Self.access(defaults: defaults).adopt(.member)

    let fetcher = MockEntitlementFetcher(answers: [.failure(.init())])
    let access = Self.access(store: .none, fetcher: fetcher, defaults: defaults)
    await access.refresh()
    #expect(access.hasPremium)
  }

  // MARK: - Identity

  @Test("Signing out forgets the server's answer")
  func signOutForgets() {
    let defaults = Self.makeDefaults()
    let access = Self.access(defaults: defaults)
    access.identify(userID: "u1")
    access.adopt(.member)
    access.identify(userID: nil)
    #expect(access.server == nil)
    #expect(!access.hasPremium)
    #expect(Self.access(defaults: defaults).server == nil)
  }

  @Test("A different member never inherits the last one's answer")
  func otherMemberStartsFresh() {
    let defaults = Self.makeDefaults()
    let first = Self.access(defaults: defaults)
    first.identify(userID: "u1")
    first.adopt(.member)

    let next = Self.access(defaults: defaults)
    next.identify(userID: "u2")
    #expect(next.server == nil)
    #expect(!next.hasPremium)
  }

  @Test("The same member relaunching keeps their answer")
  func sameMemberKeeps() {
    let defaults = Self.makeDefaults()
    let first = Self.access(defaults: defaults)
    first.identify(userID: "u1")
    first.adopt(.member)

    let relaunched = Self.access(defaults: defaults)
    relaunched.identify(userID: "u1")
    #expect(relaunched.hasPremium)
  }

  // MARK: - Grace window

  @Test("A purchase unlocks at once, then the window expires on its own")
  func graceWindowOpensAndExpires() {
    let clock = Clock()
    let access = Self.access(store: .none, clock: clock)
    access.didPurchase()
    #expect(access.hasPremium)

    clock.now += PremiumAccess.graceWindow - 1
    access.reconcile()
    #expect(access.hasPremium)

    clock.now += 2
    access.reconcile()
    #expect(!access.hasPremium)
  }

  @Test("After a purchase the server is nudged once, then polled until it agrees")
  func confirmationLadderStopsWhenServerAgrees() async {
    let fetcher = MockEntitlementFetcher(answers: [
      .success(.lapsed),
      .success(.member),
      .success(.member),
    ])
    let access = Self.access(store: .none, fetcher: fetcher)
    await access.confirmPurchase()
    #expect(fetcher.refreshCalls == 1)
    #expect(access.server == true)
    // It stopped asking the moment the server agreed: two rungs of three.
    #expect(fetcher.currentCalls == 2)
  }

  @Test("The ladder ends after its last rung when the server never agrees")
  func confirmationLadderEnds() async {
    let fetcher = MockEntitlementFetcher(answers: [.success(.lapsed)])
    let access = Self.access(store: .none, fetcher: fetcher)
    await access.confirmPurchase()
    #expect(fetcher.refreshCalls == 1)
    #expect(fetcher.currentCalls == 3)
    #expect(access.server == false)
  }

  // MARK: - Flip counter

  @Test("The flip counter moves exactly once per flip")
  func flipCountOncePerFlip() {
    let access = Self.access(store: .none)
    #expect(access.flipCount == 0)

    access.adopt(.member)
    #expect(access.flipCount == 1)
    access.adopt(.member)
    access.reconcile()
    #expect(access.flipCount == 1)

    access.adopt(.lapsed)
    #expect(access.flipCount == 2)
    access.adopt(.lapsed)
    #expect(access.flipCount == 2)
  }

  @Test("The server catching up after a purchase re-fetches content without a flip")
  func serverCatchUpMovesContentEpoch() {
    let access = Self.access(store: .none)
    access.adopt(.lapsed)
    let start = access.contentEpoch
    access.didPurchase()
    #expect(access.flipCount == 1)
    #expect(access.contentEpoch == start + 1)

    // Already unlocked on the store's word; the server now releases the audio.
    access.adopt(.member)
    #expect(access.flipCount == 1)
    #expect(access.contentEpoch == start + 2)

    // Saying the same thing again moves nothing.
    access.adopt(.member)
    #expect(access.contentEpoch == start + 2)
  }

  @Test("The server's first answer, arriving under a grace window, still re-fetches")
  func firstAnswerUnderGraceMovesEpoch() {
    let access = Self.access(store: .none)
    access.didPurchase()
    let before = access.contentEpoch
    access.adopt(.member)
    #expect(access.contentEpoch == before + 1)
  }

  @Test("An answer that lands after sign-out is dropped, never inherited")
  func lateAnswerAfterSignOutDropped() async {
    let defaults = Self.makeDefaults()
    let fetcher = MockEntitlementFetcher(answers: [.success(.member)])
    let access = Self.access(fetcher: fetcher, defaults: defaults)
    access.identify(userID: "u1")
    async let late: Void = access.refresh()
    access.identify(userID: nil)
    await late
    access.identify(userID: "u2")
    #expect(access.server == nil)
    #expect(!access.hasPremium)
  }

  @Test("An ownerless remembered answer is never stamped onto the next member")
  func ownerlessAnswerForgotten() {
    let defaults = Self.makeDefaults()
    Self.access(defaults: defaults).adopt(.member)
    let next = Self.access(defaults: defaults)
    next.identify(userID: "u2")
    #expect(next.server == nil)
  }

  @Test("A grace window over an already-premium member is no flip")
  func graceOverMemberNoFlip() {
    let access = Self.access(store: .subscribed(productID: DeepProduct.yearly))
    access.didPurchase()
    #expect(access.flipCount == 0)
  }

  @Test("The store settling reaches the answer without anyone calling in")
  func storeObservationFlips() async throws {
    let store = MockSubscriptionStore(status: .none)
    let access = PremiumAccess(store: store, defaults: Self.makeDefaults())
    _ = try await store.purchase(MockSubscriptionStore.samplePlans[0])
    for _ in 0..<50 where !access.hasPremium {
      await Task.yield()
    }
    #expect(access.hasPremium)
    #expect(access.flipCount == 1)
  }

  // MARK: - Wire

  @Test("/me decodes with and without the entitlement key")
  func meDecodes() throws {
    let user = #"{"id":"u1","email":"a@b.c","displayName":"A","role":"USER"}"#
    let legacy = try JSONDecoder().decode(MeResponseDTO.self, from: Data(#"{"user":\#(user)}"#.utf8))
    #expect(legacy.entitlement == nil)

    let current = try JSONDecoder().decode(
      MeResponseDTO.self,
      from: Data(#"""
      {"user":\#(user),"entitlement":{"active":true,"productId":"deep.pro.yearly",
      "expiresAt":"2026-11-01T10:00:00.000Z","willRenew":true,"periodType":"TRIAL",
      "inGracePeriod":false,"store":"APP_STORE"}}
      """#.utf8)
    )
    let entitlement = try #require(current.entitlement.map(ServerEntitlement.init(dto:)))
    #expect(entitlement.isActive)
    #expect(entitlement.productID == DeepProduct.yearly)
    #expect(entitlement.expiresAt != nil)
    #expect(entitlement.periodType == "TRIAL")
    #expect(entitlement.store == "APP_STORE")
  }

  @Test("A sparse entitlement still decodes, with defaults")
  func sparseEntitlementDecodes() throws {
    let dto = try JSONDecoder().decode(EntitlementDTO.self, from: Data(#"{"active":false}"#.utf8))
    let entitlement = ServerEntitlement(dto: dto)
    #expect(!entitlement.isActive)
    #expect(!entitlement.willRenew)
    #expect(!entitlement.inGracePeriod)
  }
}
