import Foundation

/// A purchasable Deep Pro plan, projected from a StoreKit `Product` (or, later,
/// a RevenueCat `Package`) so the paywall UI never depends on the store SDK.
struct SubscriptionPlan: Identifiable, Equatable {
  enum Period: Equatable {
    case monthly
    case yearly
  }

  /// Store product identifier, e.g. `deep.pro.yearly`.
  let id: String
  let period: Period
  /// Localised price as the store formats it, e.g. "$59.99".
  let displayPrice: String
  /// Short price-per-period label, e.g. "$4.99/mo".
  var perMonthLabel: String? = nil
  /// Optional free-trial note, e.g. "7-day free trial".
  var trialNote: String? = nil

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
