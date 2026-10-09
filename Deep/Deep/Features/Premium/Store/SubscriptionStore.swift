import SwiftUI
import Observation

/// The paywall's purchasing surface. The UI depends on this protocol, never on
/// RevenueCat directly, so the paywall previews against `MockSubscriptionStore`
/// offline. `RevenueCatSubscriptionStore` is the one live conformer.
protocol SubscriptionStore: AnyObject, Observable {
  var status: SubscriptionState { get }
  var plans: [SubscriptionPlan] { get }
  var isSubscribed: Bool { get }

  /// Fetch the available plans from the store. Safe to call repeatedly.
  func loadPlans() async
  func purchase(_ plan: SubscriptionPlan) async throws -> PurchaseOutcome
  func restore() async throws
}

extension SubscriptionStore {
  var isSubscribed: Bool {
    if case .subscribed = status { return true }
    return false
  }
}

/// What came of a purchase attempt.
///
/// Backing out and Ask-to-Buy are ordinary outcomes, not errors: the paywall
/// stands down in silence for one and says something quiet for the other. A
/// thrown error means the purchase genuinely failed. Without this the three
/// are indistinguishable, and a family purchase awaiting approval would look
/// exactly like a change of heart.
enum PurchaseOutcome: Equatable {
  case purchased
  case cancelled
  case pending
}

/// Product identifiers for DEEP Premium — the same ids in `Deep.storekit`, the
/// RevenueCat Test Store, and (once created) App Store Connect. Unchanged from
/// the product's former name: an App Store Connect product id can never be
/// reused. `nonisolated` so they read as the plain compile-time constants they
/// are from any isolation.
enum DeepProduct {
  nonisolated static let monthly = "deep.pro.monthly"
  nonisolated static let yearly = "deep.pro.yearly"
  nonisolated static let all = [yearly, monthly]
}

/// The RevenueCat entitlement both products unlock — the DEEP Premium project's
/// identifier, and the one deep-api's webhook reads (`REVENUECAT_ENTITLEMENT_ID`).
enum DeepEntitlement {
  nonisolated static let id = "deep_premium"
}

extension EnvironmentValues {
  /// The default is the offline mock so paywall previews are hermetic; the real
  /// `RevenueCatSubscriptionStore` is built in `AppDependencies` and injected at
  /// `AppRootView` — and again inside the UIKit tab shell, which the SwiftUI
  /// environment does not survive.
  @Entry var subscriptionStore: any SubscriptionStore = PreviewSubscriptionStore()
}

/// A tiny always-available stand-in for the `@Entry` default (the DEBUG-only
/// `MockSubscriptionStore` can't be referenced from non-DEBUG default values).
@MainActor
@Observable
final class PreviewSubscriptionStore: SubscriptionStore {
  var status: SubscriptionState = .none
  var plans: [SubscriptionPlan] = []
  func loadPlans() async {}
  func purchase(_ plan: SubscriptionPlan) async throws -> PurchaseOutcome { .cancelled }
  func restore() async throws {}
}
