import Foundation
import Observation
import StoreKit

/// `SubscriptionStore` backed by StoreKit 2.
///
/// In development it reads products from the bundled `Deep.storekit`
/// configuration (referenced by the run scheme); in production it reads the same
/// product IDs from App Store Connect. The last-known entitlement is cached in
/// `UserDefaults` so the paywall can render the right state immediately on launch
/// without awaiting a network round-trip.
@MainActor
@Observable
final class StoreKitSubscriptionStore: SubscriptionStore {
  @ObservationIgnored private let cache: SubscriptionStatusCache

  private(set) var status: SubscriptionState {
    didSet { cache.save(status) }
  }
  private(set) var plans: [SubscriptionPlan] = []

  /// Keep StoreKit `Product`s around so a `SubscriptionPlan.id` can be mapped
  /// back to the thing we actually purchase.
  private var products: [String: Product] = [:]
  private var updatesTask: Task<Void, Never>?

  /// The cache is built here rather than as a default argument: a default
  /// argument is evaluated at the call site, which is nonisolated, and this
  /// type is not.
  init(cache: SubscriptionStatusCache? = nil) {
    let cache = cache ?? SubscriptionStatusCache()
    self.cache = cache
    // The local binding, not `self.cache`: nothing may touch `self` until every
    // stored property is initialised.
    status = cache.load() ?? .unknown
    // Stay current with renewals, refunds, and purchases made elsewhere.
    updatesTask = Task { [weak self] in
      for await update in Transaction.updates {
        guard let self else { return }
        if case .verified(let transaction) = update {
          await self.refreshStatus()
          await transaction.finish()
        }
      }
    }
  }

  // No `deinit` cancellation: this store is injected once at `AppRootView` and
  // lives for the app's lifetime. The `[weak self]` listener ends on its own if
  // the store is ever released. (A nonisolated `deinit` cannot touch the
  // MainActor-isolated `updatesTask` under strict concurrency anyway.)

  func loadPlans() async {
    do {
      let storeProducts = try await Product.products(for: DeepProduct.all)
      products = Dictionary(uniqueKeysWithValues: storeProducts.map { ($0.id, $0) })
      // Preserve the canonical order (yearly first) regardless of store order.
      var loaded: [SubscriptionPlan] = []
      for id in DeepProduct.all {
        guard let product = products[id] else { continue }
        loaded.append(await Self.plan(from: product))
      }
      plans = loaded
      await refreshStatus()
    } catch {
      // Walking away is not the store being unreachable. `loadPlans()` is
      // driven from `.task`, so popping Settings or swiping the paywall away
      // mid-query cancels it — and clearing below would then cache `.none` for
      // a real subscriber, locking their sounds until something re-queries.
      if Task.isCancelled || error is CancellationError { return }
      // Offline or misconfigured store — leave plans empty; the paywall shows a
      // gentle fallback and "Not right now" still works.
      plans = []
      // With the store unreachable `.unknown` would never resolve, leaving
      // status UI on "Checking…" forever. No cached entitlement + no store =
      // treat as not subscribed; a real entitlement corrects it on the next
      // successful load or transaction update.
      if status == .unknown { status = .none }
    }
  }

  func purchase(_ plan: SubscriptionPlan) async throws -> PurchaseOutcome {
    // Nothing loaded to buy. Nothing happened, so say nothing — the same
    // standing-down the member's own "cancel" produces.
    guard let product = products[plan.id] else { return .cancelled }
    let result = try await product.purchase()
    switch result {
    case .success(let verification):
      if case .verified(let transaction) = verification {
        await transaction.finish()
        await refreshStatus()
        return .purchased
      }
      // An unverified transaction is not an entitlement we will honour.
      return .cancelled
    case .userCancelled:
      return .cancelled
    case .pending:
      return .pending
    @unknown default:
      return .cancelled
    }
  }

  func restore() async throws {
    do {
      try await AppStore.sync()
    } catch StoreKitError.userCancelled {
      // Dismissing the App Store sign-in prompt is neither success nor
      // failure — surface it as the SDK-agnostic cancellation so callers can
      // stand down quietly without importing StoreKit.
      throw CancellationError()
    }
    await refreshStatus()
  }

  /// Recompute entitlement from the user's current verified entitlements.
  private func refreshStatus() async {
    for await entitlement in Transaction.currentEntitlements {
      if case .verified(let transaction) = entitlement,
         DeepProduct.all.contains(transaction.productID),
         transaction.revocationDate == nil {
        status = .subscribed(productID: transaction.productID)
        return
      }
    }
    status = .none
  }

  // MARK: - Mapping

  private static func plan(from product: Product) async -> SubscriptionPlan {
    let period: SubscriptionPlan.Period =
      product.id == DeepProduct.yearly ? .yearly : .monthly
    let trial = await trial(for: product)
    return SubscriptionPlan(
      id: product.id,
      period: period,
      displayPrice: product.displayPrice,
      price: product.price,
      currency: product.priceFormatStyle,
      perMonthLabel: SubscriptionPlanFormatting.perMonthLabel(
        period: period,
        displayPrice: product.displayPrice,
        price: product.price,
        currency: product.priceFormatStyle
      ),
      trialNote: trial.map {
        SubscriptionPlanFormatting.trialNote(count: $0.count, unit: $0.unit)
      },
      freeTrialDays: trial.flatMap {
        SubscriptionPlanFormatting.trialDays(count: $0.count, unit: $0.unit)
      }
    )
  }

  /// The free trial this member can still take, narrowed to plain values.
  ///
  /// `introductoryOffer` is non-nil even for someone who has already used
  /// theirs, so eligibility is asked for explicitly: promising free days to a
  /// member who cannot have them is both a lie and an App Review rejection.
  private static func trial(for product: Product) async -> (count: Int, unit: SubscriptionPlanFormatting.PeriodUnit)? {
    guard let subscription = product.subscription,
          let offer = subscription.introductoryOffer,
          offer.paymentMode == .freeTrial,
          await subscription.isEligibleForIntroOffer else { return nil }
    return (offer.period.value, unit(offer.period.unit))
  }

  /// Narrow StoreKit's period unit to our own.
  ///
  /// Internal rather than private so the mapping — including StoreKit's
  /// unknown-unit fallback — is reachable from the tests.
  static func unit(_ unit: Product.SubscriptionPeriod.Unit) -> SubscriptionPlanFormatting.PeriodUnit {
    switch unit {
    case .day: return .day
    case .week: return .week
    case .month: return .month
    case .year: return .year
    @unknown default: return .day
    }
  }
}
