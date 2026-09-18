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
//          offering's `availablePackages` → `SubscriptionPlan`, building the
//          labels with `SubscriptionPlanFormatting` — the same recipe the
//          StoreKit conformer uses, so the two can never quote a price
//          differently.
//        - purchase(_:): `Purchases.shared.purchase(package:)`, then map
//          `CustomerInfo.entitlements` → `SubscriptionState`, and report
//          `userCancelled` as `.cancelled` rather than throwing.
//        - restore():    `Purchases.shared.restorePurchases()`.
//        - status:       derive from `entitlements["pro"]?.isActive`, and
//          remember it through `SubscriptionStatusCache` so a build that
//          switches conformers still reads the last-known entitlement.
//   4. Swap the construction in `AppDependencies` from
//      `StoreKitSubscriptionStore()` to `RevenueCatSubscriptionStore()`.
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

  func purchase(_ plan: SubscriptionPlan) async throws -> PurchaseOutcome {
    assertionFailure("RevenueCat adapter not wired — see RevenueCatSubscriptionStore.swift")
    return .cancelled
  }

  func restore() async throws {
    assertionFailure("RevenueCat adapter not wired — see RevenueCatSubscriptionStore.swift")
  }
}
