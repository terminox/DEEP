#if DEBUG
import Foundation
import Observation

/// In-memory `SubscriptionStore` for previews, tests and the simulator — plans
/// in code, no StoreKit, no network.
///
/// Its two behaviour knobs exist so every paywall state can be staged from a
/// preview: a store that never answers, one that can't be reached, a purchase
/// that fails, one awaiting a parent's approval.
@MainActor
@Observable
final class MockSubscriptionStore: SubscriptionStore {
  /// What `loadPlans()` does. `hangs` never returns, which parks the caller in
  /// its loading state for as long as a preview is open.
  enum Loading: Equatable {
    case succeeds
    case hangs
    case fails
  }

  /// What `purchase(_:)` does.
  enum Purchasing: Equatable {
    case succeeds
    case cancels
    case pends
    case fails
  }

  struct Failure: Error {}

  private(set) var status: SubscriptionState
  private(set) var plans: [SubscriptionPlan]

  /// What a successful load produces. Held separately from `plans` so a
  /// fixture that starts empty still ends up with the plans it was given.
  private let catalogue: [SubscriptionPlan]
  private let loading: Loading
  private let purchasing: Purchasing

  init(
    status: SubscriptionState = .none,
    plans: [SubscriptionPlan] = MockSubscriptionStore.samplePlans,
    loading: Loading = .succeeds,
    purchasing: Purchasing = .succeeds
  ) {
    self.status = status
    self.catalogue = plans
    self.plans = loading == .succeeds ? plans : []
    self.loading = loading
    self.purchasing = purchasing
  }

  func loadPlans() async {
    switch loading {
    case .succeeds:
      plans = catalogue
    case .hangs:
      plans = []
      // Park. A preview lives and dies inside this sleep, holding the skeleton.
      try? await Task.sleep(for: .seconds(60 * 60))
    case .fails:
      // An unreachable store reports nothing, exactly as the real one does.
      plans = []
    }
  }

  func purchase(_ plan: SubscriptionPlan) async throws -> PurchaseOutcome {
    switch purchasing {
    case .succeeds:
      status = .subscribed(productID: plan.id)
      return .purchased
    case .cancels:
      return .cancelled
    case .pends:
      return .pending
    case .fails:
      throw Failure()
    }
  }

  func restore() async throws {}

  /// The currency the fixtures are priced in. A fixed locale, so a preview
  /// renders the same money on any machine.
  nonisolated static let currency = Decimal.FormatStyle.Currency(
    code: "USD",
    locale: Locale(identifier: "en_US")
  )

  nonisolated static let samplePlans: [SubscriptionPlan] = [
    plan(id: DeepProduct.yearly, period: .yearly, price: "91.98", trialDays: 7),
    plan(id: DeepProduct.monthly, period: .monthly, price: "19.98", trialDays: 7),
  ]

  /// What the bundled `Deep.storekit` actually describes today: a free trial on
  /// the year, none on the month. The paywall must then put the claim on the
  /// row that owns it rather than over both.
  nonisolated static let mixedTrialPlans: [SubscriptionPlan] = [
    plan(id: DeepProduct.yearly, period: .yearly, price: "91.98", trialDays: 7),
    plan(id: DeepProduct.monthly, period: .monthly, price: "19.98", trialDays: nil),
  ]

  /// Builds a fixture through the same recipe the real store uses, so the mock
  /// and StoreKit can never quote a price differently.
  private nonisolated static func plan(
    id: String,
    period: SubscriptionPlan.Period,
    price: String,
    trialDays: Int?
  ) -> SubscriptionPlan {
    // Decimals come from strings: a float literal would round 19.98 before the
    // formatter ever sees it.
    let amount = Decimal(string: price) ?? 0
    let displayPrice = currency.format(amount)
    return SubscriptionPlan(
      id: id,
      period: period,
      displayPrice: displayPrice,
      price: amount,
      currency: currency,
      perMonthLabel: SubscriptionPlanFormatting.perMonthLabel(
        period: period,
        displayPrice: displayPrice,
        price: amount,
        currency: currency
      ),
      trialNote: trialDays.map {
        SubscriptionPlanFormatting.trialNote(count: $0, unit: .day)
      },
      freeTrialDays: trialDays
    )
  }
}

extension MockSubscriptionStore {
  static var free: MockSubscriptionStore { MockSubscriptionStore(status: .none) }

  static var subscribed: MockSubscriptionStore {
    MockSubscriptionStore(status: .subscribed(productID: DeepProduct.yearly))
  }

  /// Only one plan carries a trial, as the real StoreKit config has it.
  static var mixedTrials: MockSubscriptionStore {
    MockSubscriptionStore(plans: MockSubscriptionStore.mixedTrialPlans)
  }

  /// A store that never answers — the paywall holds its breathing skeleton.
  static var loadingPlans: MockSubscriptionStore {
    MockSubscriptionStore(plans: [], loading: .hangs)
  }

  /// A store that can't be reached — the paywall shows its quiet note.
  static var unreachable: MockSubscriptionStore {
    MockSubscriptionStore(plans: [], loading: .fails)
  }

  static var purchaseFails: MockSubscriptionStore {
    MockSubscriptionStore(purchasing: .fails)
  }
}
#endif
