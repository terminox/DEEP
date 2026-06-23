import Foundation
import Observation

// MARK: - RevenueCat drop-in (NOT ACTIVE)
//
// This is an inert placeholder so the paywall already speaks to a swappable
// `SubscriptionStore`. It intentionally does NOT import RevenueCat and is NOT
// wired into the app — `StoreKitSubscriptionStore` is the live conformer today.
//
// To activate RevenueCat later:
//   1. Add the `RevenueCat` Swift Package (https://github.com/RevenueCat/purchases-ios).
//   2. In the app entry point, call:
//        Purchases.configure(withAPIKey: "<public SDK key>")
//      (store the key in config, not source).
//   3. Implement the methods below:
//        - loadPlans():  fetch `Purchases.shared.offerings()`, map the current
//          offering's `availablePackages` → `SubscriptionPlan`
//          (`package.storeProduct.localizedPriceString`, identifiers, etc.).
//        - purchase(_:): `Purchases.shared.purchase(package:)`, then map
//          `CustomerInfo.entitlements` → `SubscriptionState`.
//        - restore():    `Purchases.shared.restorePurchases()`.
//        - status:       derive from `entitlements["pro"]?.isActive`.
//   4. Swap the injection in `AppRootView` from `StoreKitSubscriptionStore()`
//      to `RevenueCatSubscriptionStore()`.
//
// Keeping it import-free means the project builds without the SDK present.
@MainActor
@Observable
final class RevenueCatSubscriptionStore: SubscriptionStore {
  private(set) var status: SubscriptionState = .unknown
  private(set) var plans: [SubscriptionPlan] = []

  func loadPlans() async {
    assertionFailure("RevenueCat adapter not wired — see RevenueCatSubscriptionStore.swift")
  }

  func purchase(_ plan: SubscriptionPlan) async throws {
    assertionFailure("RevenueCat adapter not wired — see RevenueCatSubscriptionStore.swift")
  }

  func restore() async throws {
    assertionFailure("RevenueCat adapter not wired — see RevenueCatSubscriptionStore.swift")
  }
}
