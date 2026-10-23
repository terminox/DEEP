import Foundation

/// The arithmetic behind the paywall's two claims — what the yearly plan saves,
/// and what a member will actually be charged.
///
/// Pure and locale-free on purpose: it answers in numbers, and `PaywallCopy`
/// turns those into a sentence. That split is what lets the money be tested
/// without a `Locale` in the room, and it is why neither the savings badge nor
/// the billing line can ever be a hardcoded string.
enum PaywallPricing {
  /// What a year costs against twelve of the monthly plan, as a fraction —
  /// 0.61 for $91.98 against $19.98 a month.
  ///
  /// `nil` when there is nothing honest to claim: a missing plan, a free or
  /// nonsensical monthly price, or a year that saves nothing. Truncated rather
  /// than rounded, so a badge can only ever understate the saving.
  static func yearlySavings(monthly: Decimal, yearly: Decimal) -> Double? {
    let year = monthly * 12
    guard monthly > 0, yearly > 0, year > yearly else { return nil }
    let saved = (year - yearly) / year
    let fraction = (saved as NSDecimalNumber).doubleValue
    // Below half a percent there is no badge worth drawing.
    guard fraction >= 0.005 else { return nil }
    return (fraction * 100).rounded(.down) / 100
  }

  /// The same, read off the two plans rather than two numbers.
  static func yearlySavings(in plans: [SubscriptionPlan]) -> Double? {
    guard let monthly = plans.first(where: { $0.period == .monthly }),
          let yearly = plans.first(where: { $0.period == .yearly }) else { return nil }
    return yearlySavings(monthly: monthly.price, yearly: yearly.price)
  }

  /// What the money sentence has to say, as facts rather than as a sentence.
  enum BillingFacts: Equatable {
    case trialThenYearly(trialDays: Int, perMonth: Decimal, total: Decimal)
    case trialThenMonthly(trialDays: Int, total: Decimal)
    case yearly(perMonth: Decimal, total: Decimal)
    case monthly(total: Decimal)
  }

  static func billingFacts(for plan: SubscriptionPlan) -> BillingFacts {
    switch (plan.period, plan.freeTrialDays) {
    case (.yearly, .some(let days)):
      return .trialThenYearly(trialDays: days, perMonth: perMonth(plan.price), total: plan.price)
    case (.yearly, .none):
      return .yearly(perMonth: perMonth(plan.price), total: plan.price)
    case (.monthly, .some(let days)):
      return .trialThenMonthly(trialDays: days, total: plan.price)
    case (.monthly, .none):
      return .monthly(total: plan.price)
    }
  }

  /// A yearly price divided into twelve, left unrounded.
  ///
  /// Rounding belongs to the currency, not to this: a fixed two places would
  /// quote "KD 0.830 a month, billed yearly at KD 10.000" on the three-decimal
  /// storefronts, where twelve months no longer add up to the year on a screen
  /// whose whole job is stating the terms accurately.
  /// `SubscriptionPlanFormatting.money` does the rounding, at the currency's
  /// own precision.
  static func perMonth(_ yearlyPrice: Decimal) -> Decimal {
    yearlyPrice / 12
  }
}
