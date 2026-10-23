import Testing
import Foundation
@testable import Deep

/// The entitlement cache's contract: what goes in comes back out, the
/// transient "unknown" is never written, and anything unrecognisable reads as
/// nothing cached rather than as a guess.
@MainActor
struct SubscriptionStatusCacheTests {
  /// A fresh, empty `UserDefaults` suite scoped to one test, with its name
  /// returned so the caller can tear it down (the `PlaylistStoreTests` pattern).
  private static func makeSuite() -> (defaults: UserDefaults, name: String) {
    let name = "DeepTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return (defaults, name)
  }

  /// Mirrored from the cache, where it is private. Two conformers read each
  /// other's cache across an app update, so the key and its encoding are part
  /// of the contract, not an implementation detail — if this literal has to
  /// change, that is a migration, not a rename.
  private static let key = "deep.subscription.status"

  @Test("Nothing cached reads as nothing cached")
  func virginSuiteIsEmpty() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }

    #expect(SubscriptionStatusCache(defaults: defaults).load() == nil)
  }

  @Test("A subscription round-trips with its product id")
  func subscribedRoundTrips() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }
    let cache = SubscriptionStatusCache(defaults: defaults)

    cache.save(.subscribed(productID: DeepProduct.yearly))

    #expect(cache.load() == .subscribed(productID: DeepProduct.yearly))
  }

  @Test("A free plan round-trips as a free plan, not as nothing cached")
  func freePlanRoundTripsAndIsNotNil() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }
    let cache = SubscriptionStatusCache(defaults: defaults)

    cache.save(SubscriptionState.none)

    // The regression that matters: inside a function returning an optional, a
    // bare `.none` is `Optional.none`. Were that mistake made, a remembered
    // free plan would read as nothing cached and every launch would open on
    // "Checking…" instead of "Free plan".
    let loaded = cache.load()
    #expect(loaded != nil)
    #expect(loaded == SubscriptionState.none)
  }

  @Test("The transient unknown state is never written")
  func unknownIsNotPersisted() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }
    let cache = SubscriptionStatusCache(defaults: defaults)

    cache.save(.unknown)

    #expect(cache.load() == nil)
    #expect(defaults.string(forKey: Self.key) == nil)
  }

  @Test("Unknown does not erase what was already remembered")
  func unknownDoesNotClobber() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }
    let cache = SubscriptionStatusCache(defaults: defaults)

    cache.save(.subscribed(productID: DeepProduct.monthly))
    cache.save(.unknown)

    // A store that hasn't answered yet must not cost a member their entitlement.
    #expect(cache.load() == .subscribed(productID: DeepProduct.monthly))
  }

  @Test("An unrecognisable value reads as nothing cached")
  func garbageReadsAsNil() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }
    let cache = SubscriptionStatusCache(defaults: defaults)

    for raw in ["garbage", "subscribed", "", "Subscribed:deep.pro.yearly"] {
      defaults.set(raw, forKey: Self.key)
      #expect(cache.load() == nil, "\(raw) should not decode")
    }
  }

  @Test("The on-disk encoding is exactly what a second conformer will read")
  func onDiskEncodingIsPinned() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }
    let cache = SubscriptionStatusCache(defaults: defaults)

    cache.save(.subscribed(productID: DeepProduct.yearly))
    #expect(defaults.string(forKey: Self.key) == "subscribed:deep.pro.yearly")

    cache.save(SubscriptionState.none)
    #expect(defaults.string(forKey: Self.key) == "none")
  }

  @Test("A prefixed value with an empty id still decodes to that empty id")
  func emptyProductIDIsNotSpecialCased() {
    let (defaults, name) = Self.makeSuite()
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set("subscribed:", forKey: Self.key)

    // Not a case worth inventing a rule for — it decodes literally, and the
    // entitlement check downstream compares against known product ids anyway.
    #expect(SubscriptionStatusCache(defaults: defaults).load() == .subscribed(productID: ""))
  }
}
