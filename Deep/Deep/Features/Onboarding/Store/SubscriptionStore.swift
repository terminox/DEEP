import SwiftUI
import Observation

/// The paywall's purchasing surface. The UI depends on this protocol, never on
/// StoreKit or RevenueCat directly, so the paywall previews against
/// `MockSubscriptionStore` offline and the backing store can be swapped later.
protocol SubscriptionStore: AnyObject, Observable {
  var status: SubscriptionState { get }
  var plans: [SubscriptionPlan] { get }
  var isSubscribed: Bool { get }

  /// Fetch the available plans from the store. Safe to call repeatedly.
  func loadPlans() async
  func purchase(_ plan: SubscriptionPlan) async throws
  func restore() async throws
}

extension SubscriptionStore {
  var isSubscribed: Bool {
    if case .subscribed = status { return true }
    return false
  }
}

/// Product identifiers for Deep Pro — must match `Deep.storekit` (and, later,
/// App Store Connect / RevenueCat). `nonisolated` so they read as the plain
/// compile-time constants they are from any isolation.
enum DeepProduct {
  nonisolated static let monthly = "deep.pro.monthly"
  nonisolated static let yearly = "deep.pro.yearly"
  nonisolated static let all = [yearly, monthly]
}

extension EnvironmentValues {
  /// The default is the offline mock so paywall previews are hermetic; the real
  /// `StoreKitSubscriptionStore` is injected at `AppRootView`.
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
  func purchase(_ plan: SubscriptionPlan) async throws {}
  func restore() async throws {}
}
