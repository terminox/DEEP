#if DEBUG
import Foundation
import Observation

/// In-memory `SubscriptionStore` for previews and tests — hard-coded plans, no
/// StoreKit, no network. `purchase` flips status synchronously so the paywall
/// reacts immediately.
@MainActor
@Observable
final class MockSubscriptionStore: SubscriptionStore {
  private(set) var status: SubscriptionState
  private(set) var plans: [SubscriptionPlan]

  init(
    status: SubscriptionState = .none,
    plans: [SubscriptionPlan] = MockSubscriptionStore.samplePlans
  ) {
    self.status = status
    self.plans = plans
  }

  func loadPlans() async {}

  func purchase(_ plan: SubscriptionPlan) async throws {
    status = .subscribed(productID: plan.id)
  }

  func restore() async throws {}

  nonisolated static let samplePlans: [SubscriptionPlan] = [
    SubscriptionPlan(
      id: DeepProduct.yearly,
      period: .yearly,
      displayPrice: "$59.99",
      perMonthLabel: "$4.99/mo",
      trialNote: "7-day free trial"
    ),
    SubscriptionPlan(
      id: DeepProduct.monthly,
      period: .monthly,
      displayPrice: "$9.99",
      perMonthLabel: "$9.99/mo"
    ),
  ]
}

extension MockSubscriptionStore {
  static var free: MockSubscriptionStore { MockSubscriptionStore(status: .none) }

  static var subscribed: MockSubscriptionStore {
    MockSubscriptionStore(status: .subscribed(productID: DeepProduct.yearly))
  }
}
#endif
