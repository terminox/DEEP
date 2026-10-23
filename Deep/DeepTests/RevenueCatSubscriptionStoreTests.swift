import Testing
import Foundation
@testable import Deep

/// The rules the RevenueCat adapter applies to what the SDK hands it, tested
/// without the SDK: which plan leads, and what the entitlement flag means.
@MainActor
@Suite("RevenueCat adapter")
struct RevenueCatSubscriptionStoreTests {
  private static let usd = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))

  private static func plan(_ id: String, _ period: SubscriptionPlan.Period) -> SubscriptionPlan {
    SubscriptionPlan(id: id, period: period, displayPrice: "$1.00", price: 1, currency: usd)
  }

  @Test("Yearly leads whatever order the offering lists its packages in")
  func yearlyFirst() {
    let monthly = Self.plan(DeepProduct.monthly, .monthly)
    let yearly = Self.plan(DeepProduct.yearly, .yearly)
    // The DEEP Premium offering lists monthly first.
    #expect(RevenueCatSubscriptionStore.canonicalOrder([monthly, yearly]) == [yearly, monthly])
    #expect(RevenueCatSubscriptionStore.canonicalOrder([yearly, monthly]) == [yearly, monthly])
  }

  @Test("A missing plan leaves the other standing alone")
  func onePlanOnly() {
    let monthly = Self.plan(DeepProduct.monthly, .monthly)
    #expect(RevenueCatSubscriptionStore.canonicalOrder([monthly]) == [monthly])
    #expect(RevenueCatSubscriptionStore.canonicalOrder([]).isEmpty)
  }

  @Test("An active entitlement subscribes to the product that granted it")
  func activeEntitlement() {
    #expect(
      RevenueCatSubscriptionStore.state(isActive: true, productID: DeepProduct.yearly)
        == .subscribed(productID: DeepProduct.yearly)
    )
  }

  @Test("An inactive or missing entitlement is not subscribed — never unknown")
  func inactiveEntitlement() {
    #expect(RevenueCatSubscriptionStore.state(isActive: false, productID: DeepProduct.yearly) == SubscriptionState.none)
    #expect(RevenueCatSubscriptionStore.state(isActive: false, productID: nil) == SubscriptionState.none)
    // Active with no product to name can't drive the plan chip; treat as none
    // rather than invent one.
    #expect(RevenueCatSubscriptionStore.state(isActive: true, productID: nil) == SubscriptionState.none)
  }

  @Test("With no API key the store reads as not subscribed and offers nothing")
  func noKeyDegrades() async throws {
    let defaults = try #require(UserDefaults(suiteName: "RevenueCatSubscriptionStoreTests.noKey"))
    defaults.removePersistentDomain(forName: "RevenueCatSubscriptionStoreTests.noKey")
    // Even a cached entitlement can't stand without a store to confirm it.
    let cache = SubscriptionStatusCache(defaults: defaults)
    cache.save(.subscribed(productID: DeepProduct.yearly))

    let store = RevenueCatSubscriptionStore(apiKey: nil, cache: cache)
    #expect(store.status == SubscriptionState.none)
    await store.loadPlans()
    #expect(store.plans.isEmpty)
    let outcome = try await store.purchase(Self.plan(DeepProduct.yearly, .yearly))
    #expect(outcome == .cancelled)
  }
}

@Suite("Account identity")
struct AccountIdentityTests {
  @Test("An identity cached before the user id existed still decodes")
  func legacyCacheDecodes() throws {
    let legacy = Data(#"{"displayName":"Mali","email":"mali@deep.test","method":"email"}"#.utf8)
    let account = try JSONDecoder().decode(Account.self, from: legacy)
    #expect(account.displayName == "Mali")
    #expect(account.userID == nil)
  }

  @Test("The user id survives the cache round trip")
  func userIDRoundTrips() throws {
    let account = Account(displayName: "Mali", email: nil, method: .email, appleUserID: nil, userID: "6f1c0e1a-0000-4000-8000-000000000001")
    let decoded = try JSONDecoder().decode(Account.self, from: JSONEncoder().encode(account))
    #expect(decoded == account)
  }
}
