import Foundation

/// A purchasable DEEP Premium plan, projected from a StoreKit `Product` (or,
/// later, a RevenueCat `Package`) so the paywall UI never depends on the store
/// SDK.
///
/// It carries both the store's own strings (`displayPrice`, `perMonthLabel`)
/// and the numbers behind them (`price`, `currency`, `freeTrialDays`). The
/// paywall shows the strings and reasons about the numbers — a savings badge
/// or a billing sentence has to be derived, never hardcoded.
struct SubscriptionPlan: Identifiable, Equatable {
  enum Period: Equatable {
    case monthly
    case yearly
  }

  /// Store product identifier, e.g. `deep.pro.yearly`.
  let id: String
  let period: Period
  /// Localised price as the store formats it, e.g. "$91.98".
  let displayPrice: String
  /// The same price as a number, for arithmetic the label can't do.
  let price: Decimal
  /// How the store spells money here — its currency and its locale. Derived
  /// figures are formatted through this so they can never disagree with
  /// `displayPrice` beside them.
  let currency: Decimal.FormatStyle.Currency
  /// Short price-per-period label, e.g. "$7.67/mo".
  var perMonthLabel: String? = nil
  /// Optional free-trial note, e.g. "7-day free trial".
  var trialNote: String? = nil
  /// The trial's length in days, when the store offers one this member is
  /// still eligible for. `nil` means: promise nothing.
  var freeTrialDays: Int? = nil

  var title: String {
    switch period {
    case .monthly: return "Monthly"
    case .yearly: return "Yearly"
    }
  }
}

/// The user's known entitlement state. `.unknown` until the store is queried;
/// the paywall treats anything other than `.subscribed` as "not yet a member".
///
/// Named `SubscriptionState` (not `…Status`) deliberately, to avoid colliding
/// with StoreKit's own `SubscriptionStatus` (`Product.SubscriptionInfo.Status`).
enum SubscriptionState: Equatable {
  case unknown
  case none
  case subscribed(productID: String)
}
