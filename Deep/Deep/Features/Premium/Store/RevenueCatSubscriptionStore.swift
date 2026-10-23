import Foundation
import Observation
import RevenueCat

/// `SubscriptionStore` backed by RevenueCat — the app's one live purchase path.
///
/// RevenueCat owns purchase truth (it is StoreKit underneath, plus receipt
/// validation and the webhook that tells deep-api). This adapter only projects
/// it into the SDK-free types the paywall speaks: offerings become
/// `SubscriptionPlan`s, the `deep_premium` entitlement becomes
/// `SubscriptionState`.
///
/// **Identity is the DEEP user id, never the email.** The account store hands
/// it over through `identify(userID:)` on sign-up, login and launch, and clears
/// it on logout. A purchase is refused rather than attached to an anonymous
/// RevenueCat id — re-homing anonymous purchases later is manual surgery.
///
/// With no API key (every release environment until an App Store app exists in
/// the RevenueCat project) the store never configures the SDK and simply reads
/// as "not subscribed".
@MainActor
@Observable
final class RevenueCatSubscriptionStore: SubscriptionStore {
  /// The member tried to buy before the account's id reached RevenueCat — a
  /// purchase now would land on an anonymous customer.
  struct IdentityUnavailable: Error {}

  @ObservationIgnored private let cache: SubscriptionStatusCache

  private(set) var status: SubscriptionState {
    didSet { cache.save(status) }
  }
  private(set) var plans: [SubscriptionPlan] = []

  /// The SDK's packages, keyed by `SubscriptionPlan.id`, so a plan can be
  /// mapped back to the thing we actually purchase.
  @ObservationIgnored private var packages: [String: Package] = [:]
  /// The DEEP user id RevenueCat should be speaking for, as last reported by
  /// the account store. `nil` means signed out.
  @ObservationIgnored private var expectedUserID: String?
  @ObservationIgnored private let isConfigured: Bool
  @ObservationIgnored private var updatesTask: Task<Void, Never>?

  /// - Parameters:
  ///   - apiKey: RevenueCat's public SDK key; `nil` leaves the SDK unconfigured.
  ///   - appUserID: the last signed-in DEEP user id, if any, so a returning
  ///     member's launch never creates an anonymous customer first.
  init(apiKey: String?, appUserID: String? = nil, cache: SubscriptionStatusCache? = nil) {
    let cache = cache ?? SubscriptionStatusCache()
    self.cache = cache
    self.expectedUserID = appUserID
    // The local binding, not `self.cache`: nothing may touch `self` until every
    // stored property is initialised.
    let cached = cache.load()

    guard let apiKey else {
      isConfigured = false
      // No store at all can never resolve `.unknown`, so a status chip would
      // read "Checking…" forever. No key = not subscribed.
      status = .none
      return
    }
    isConfigured = true
    status = cached ?? .unknown

    var configuration = Configuration.Builder(withAPIKey: apiKey).with(appUserID: appUserID)
    #if DEBUG
    Purchases.logLevel = .info
    // RevenueCat crashes a "release" build carrying a Test Store key — and it
    // judges that by *its own* `DEBUG` flag. Xcode compiles Swift packages
    // under a custom configuration like `Dev` as release, so without this the
    // Dev build trips the guard. Our own `DEBUG` is the truthful signal, and no
    // shipping environment both compiles it in and carries a test key.
    configuration = configuration.with(
      dangerousSettings: DangerousSettings(autoSyncPurchases: true, forceAllowTestStoreInReleaseBuilds: true)
    )
    #endif
    Purchases.configure(with: configuration.build())

    // Renewals, refunds, expiries and purchases made on another device all
    // arrive here — the role StoreKit's `Transaction.updates` listener played.
    // The stream also yields the current info straight away.
    updatesTask = Task { [weak self] in
      for await info in Purchases.shared.customerInfoStream {
        guard let self else { return }
        self.apply(info)
      }
    }
  }

  // No `deinit` cancellation: this store is built once in `AppDependencies` and
  // lives for the app's lifetime. The `[weak self]` listener ends on its own if
  // the store is ever released.

  // MARK: - SubscriptionStore

  func loadPlans() async {
    guard isConfigured else { return }
    do {
      let offerings = try await Purchases.shared.offerings()
      let available = offerings.current?.availablePackages ?? []
      var loaded: [SubscriptionPlan] = []
      var byID: [String: Package] = [:]
      for package in available {
        guard let period = Self.period(of: package) else { continue }
        let plan = await Self.plan(from: package.storeProduct, period: period)
        loaded.append(plan)
        byID[plan.id] = package
      }
      packages = byID
      plans = Self.canonicalOrder(loaded)
      apply(try await Purchases.shared.customerInfo())
    } catch {
      // Walking away is not the store being unreachable. `loadPlans()` is
      // driven from `.task`, so popping Settings or swiping the paywall away
      // mid-query cancels it — and clearing below would then cache `.none` for
      // a real subscriber.
      if Task.isCancelled || error is CancellationError { return }
      // Offline or misconfigured — leave plans empty; the paywall shows its
      // gentle fallback and "Not right now" still works.
      plans = []
      // With the store unreachable `.unknown` would never resolve. No cached
      // entitlement + no store = not subscribed; a real entitlement corrects it
      // on the next successful load or customer-info update.
      if status == .unknown { status = .none }
    }
  }

  func purchase(_ plan: SubscriptionPlan) async throws -> PurchaseOutcome {
    // Nothing loaded to buy. Nothing happened, so say nothing — the same
    // standing-down the member's own "cancel" produces.
    guard isConfigured, let package = packages[plan.id] else { return .cancelled }
    try await ensureIdentified()
    do {
      let result = try await Purchases.shared.purchase(package: package)
      if result.userCancelled { return .cancelled }
      apply(result.customerInfo)
      return .purchased
    } catch let error as RevenueCat.ErrorCode {
      switch error {
      case .purchaseCancelledError: return .cancelled
      case .paymentPendingError: return .pending
      default: throw error
      }
    }
  }

  func restore() async throws {
    guard isConfigured else { return }
    try await ensureIdentified()
    do {
      apply(try await Purchases.shared.restorePurchases())
    } catch RevenueCat.ErrorCode.purchaseCancelledError {
      // Dismissing the App Store sign-in prompt is neither success nor
      // failure — surface it as the SDK-agnostic cancellation so callers can
      // stand down quietly without importing RevenueCat.
      throw CancellationError()
    }
  }

  // MARK: - Identity

  /// Point RevenueCat at this DEEP user, or back to anonymous on sign-out.
  ///
  /// Failures are quiet: the id is remembered, and `purchase` / `restore`
  /// retry the login before they act, so a flaky network at sign-up can delay
  /// identification but never let a purchase land anonymously.
  func identify(userID: String?) async {
    expectedUserID = userID
    guard isConfigured else { return }
    if let userID {
      guard Purchases.shared.appUserID != userID else { return }
      if let (info, _) = try? await Purchases.shared.logIn(userID) {
        apply(info)
      }
    } else {
      // Already anonymous is the one expected "failure" here; either way the
      // previous member's entitlement must not linger on this device.
      if !Purchases.shared.isAnonymous, let info = try? await Purchases.shared.logOut() {
        apply(info)
      } else {
        status = .none
      }
    }
  }

  /// Make sure RevenueCat speaks for the signed-in member before money moves.
  private func ensureIdentified() async throws {
    guard let expectedUserID else { throw IdentityUnavailable() }
    guard Purchases.shared.appUserID != expectedUserID else { return }
    apply(try await Purchases.shared.logIn(expectedUserID).customerInfo)
  }

  // MARK: - Mapping

  private func apply(_ info: CustomerInfo) {
    let entitlement = info.entitlements[DeepEntitlement.id]
    status = Self.state(
      isActive: entitlement?.isActive ?? false,
      productID: entitlement?.productIdentifier
    )
  }

  /// The entitlement's active flag, narrowed to our state. Internal so the
  /// rule is reachable from the tests without the SDK.
  nonisolated static func state(isActive: Bool, productID: String?) -> SubscriptionState {
    guard isActive, let productID else { return .none }
    return .subscribed(productID: productID)
  }

  /// Yearly first, whatever order the offering lists its packages in — the
  /// paywall preselects the first plan.
  static func canonicalOrder(_ plans: [SubscriptionPlan]) -> [SubscriptionPlan] {
    plans.filter { $0.period == .yearly } + plans.filter { $0.period == .monthly }
  }

  private static func period(of package: Package) -> SubscriptionPlan.Period? {
    switch package.packageType {
    case .annual: return .yearly
    case .monthly: return .monthly
    default: return nil
    }
  }

  private static func plan(from product: StoreProduct, period: SubscriptionPlan.Period) async -> SubscriptionPlan {
    let currency = Self.currency(of: product)
    let trial = await trial(for: product)
    return SubscriptionPlan(
      id: product.productIdentifier,
      period: period,
      displayPrice: product.localizedPriceString,
      price: product.price,
      currency: currency,
      perMonthLabel: SubscriptionPlanFormatting.perMonthLabel(
        period: period,
        displayPrice: product.localizedPriceString,
        price: product.price,
        currency: currency
      ),
      trialNote: trial.map {
        SubscriptionPlanFormatting.trialNote(count: $0.count, unit: $0.unit)
      },
      freeTrialDays: trial.flatMap {
        SubscriptionPlanFormatting.trialDays(count: $0.count, unit: $0.unit)
      }
    )
  }

  /// The storefront's currency and locale as a Foundation format style — the
  /// same type StoreKit's `priceFormatStyle` is, so every derived figure is
  /// spelled exactly like the price beside it.
  private static func currency(of product: StoreProduct) -> Decimal.FormatStyle.Currency {
    let locale = product.priceFormatter?.locale ?? .current
    let code = product.currencyCode
      ?? product.priceFormatter?.currencyCode
      ?? locale.currency?.identifier
      ?? "USD"
    return Decimal.FormatStyle.Currency(code: code, locale: locale)
  }

  /// The free trial this member can still take, narrowed to plain values.
  ///
  /// The intro offer exists whether or not this member has already used it, so
  /// eligibility is asked for explicitly: promising free days to someone who
  /// cannot have them is both a lie and an App Review rejection.
  private static func trial(for product: StoreProduct) async -> (count: Int, unit: SubscriptionPlanFormatting.PeriodUnit)? {
    guard let offer = product.introductoryDiscount, offer.paymentMode == .freeTrial else { return nil }
    let eligibility = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product)
    guard eligibility == .eligible else { return nil }
    return (offer.subscriptionPeriod.value, unit(offer.subscriptionPeriod.unit))
  }

  private static func unit(_ unit: SubscriptionPeriod.Unit) -> SubscriptionPlanFormatting.PeriodUnit {
    switch unit {
    case .day: return .day
    case .week: return .week
    case .month: return .month
    case .year: return .year
    @unknown default: return .day
    }
  }
}
