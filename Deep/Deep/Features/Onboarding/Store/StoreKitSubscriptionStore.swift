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
  private static let statusKey = "deep.subscription.status"

  private(set) var status: SubscriptionState {
    didSet { cacheStatus() }
  }
  private(set) var plans: [SubscriptionPlan] = []

  /// Keep StoreKit `Product`s around so a `SubscriptionPlan.id` can be mapped
  /// back to the thing we actually purchase.
  private var products: [String: Product] = [:]
  private var updatesTask: Task<Void, Never>?

  init() {
    status = Self.cachedStatus() ?? .unknown
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
      plans = DeepProduct.all.compactMap { products[$0].map(Self.plan(from:)) }
      await refreshStatus()
    } catch {
      // Offline or misconfigured store — leave plans empty; the paywall shows a
      // gentle fallback and "Maybe later" still works.
      plans = []
      // With the store unreachable `.unknown` would never resolve, leaving
      // status UI on "Checking…" forever. No cached entitlement + no store =
      // treat as not subscribed; a real entitlement corrects it on the next
      // successful load or transaction update.
      if status == .unknown { status = .none }
    }
  }

  func purchase(_ plan: SubscriptionPlan) async throws {
    guard let product = products[plan.id] else { return }
    let result = try await product.purchase()
    switch result {
    case .success(let verification):
      if case .verified(let transaction) = verification {
        await transaction.finish()
        await refreshStatus()
      }
    case .userCancelled, .pending:
      break
    @unknown default:
      break
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

  private static func plan(from product: Product) -> SubscriptionPlan {
    let period: SubscriptionPlan.Period =
      product.id == DeepProduct.yearly ? .yearly : .monthly
    return SubscriptionPlan(
      id: product.id,
      period: period,
      displayPrice: product.displayPrice,
      perMonthLabel: perMonthLabel(for: product, period: period),
      trialNote: trialNote(for: product)
    )
  }

  /// For a yearly plan, show the effective per-month cost; for monthly, the
  /// price itself.
  private static func perMonthLabel(for product: Product, period: SubscriptionPlan.Period) -> String? {
    switch period {
    case .monthly:
      return "\(product.displayPrice)/mo"
    case .yearly:
      let monthly = product.price / 12
      let formatted = product.priceFormatStyle.format(monthly)
      return "\(formatted)/mo"
    }
  }

  private static func trialNote(for product: Product) -> String? {
    guard let offer = product.subscription?.introductoryOffer,
          offer.paymentMode == .freeTrial else { return nil }
    let unit = offer.period.unit
    let count = offer.period.value
    let unitName: String
    switch unit {
    case .day: unitName = "day"
    case .week: unitName = "week"
    case .month: unitName = "month"
    case .year: unitName = "year"
    @unknown default: unitName = "day"
    }
    return "\(count)-\(unitName) free trial"
  }

  // MARK: - Cached status

  private func cacheStatus() {
    let raw: String
    switch status {
    case .subscribed(let id): raw = "subscribed:\(id)"
    case .none: raw = "none"
    case .unknown: return // don't cache the transient unknown state
    }
    UserDefaults.standard.set(raw, forKey: Self.statusKey)
  }

  private static func cachedStatus() -> SubscriptionState? {
    guard let raw = UserDefaults.standard.string(forKey: statusKey) else { return nil }
    if raw == "none" { return SubscriptionState.none }
    if raw.hasPrefix("subscribed:") {
      return .subscribed(productID: String(raw.dropFirst("subscribed:".count)))
    }
    return nil
  }
}
