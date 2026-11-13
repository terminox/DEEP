import Foundation

/// The one recipe for turning a store's raw numbers into the short labels a
/// paywall shows.
///
/// It takes plain values — a `Decimal` and a count of a calendar unit — rather
/// than a StoreKit `Product`, so a RevenueCat package can use the identical
/// recipe. Two conformers must never format the same price differently.
enum SubscriptionPlanFormatting {
  /// A trial length as the stores express it: a count of a calendar unit.
  /// Mirrors StoreKit's `Product.SubscriptionPeriod.Unit` without importing it.
  enum PeriodUnit: Equatable, Sendable {
    case day
    case week
    case month
    case year
  }

  /// A free trial as the store records it, kept as numbers so the sentence
  /// that names it is written at display time, in the reading language.
  struct Trial: Equatable, Sendable {
    let count: Int
    let unit: PeriodUnit
  }

  /// For a yearly plan, the effective per-month cost; for a monthly plan, the
  /// price itself, passed through exactly as the store already formatted it.
  ///
  /// `currency` arrives from the store (StoreKit's `priceFormatStyle` is this
  /// very type, built from the storefront's locale), so the divided price is
  /// spelled in the same currency and locale as the price beside it.
  nonisolated static func perMonthLabel(
    period: SubscriptionPlan.Period,
    displayPrice: String,
    price: Decimal,
    currency: Decimal.FormatStyle.Currency
  ) -> String {
    switch period {
    case .monthly:
      return "\(displayPrice)/mo"
    case .yearly:
      return "\(perMonthPrice(yearlyPrice: price, currency: currency))/mo"
    }
  }

  /// A yearly price as a monthly figure, in the store's own currency.
  ///
  /// The one place that division and its rounding happen. Everything that
  /// quotes a month — the plan row, the billing sentence, the compact label —
  /// comes through here, so they cannot disagree by a penny.
  nonisolated static func perMonthPrice(
    yearlyPrice: Decimal,
    currency: Decimal.FormatStyle.Currency
  ) -> String {
    money(yearlyPrice / 12, currency: currency)
  }

  /// Money, rounded the way money rounds.
  ///
  /// `Decimal.FormatStyle` defaults to half-to-even, which turns an exact tie —
  /// 91.98 / 12 = 7.665 — into $7.66, a cent below the figure the member is
  /// quoted. The currency keeps its own precision, so a three-decimal
  /// storefront (KWD, BHD) still renders three.
  nonisolated static func money(
    _ amount: Decimal,
    currency: Decimal.FormatStyle.Currency
  ) -> String {
    currency.rounded(rule: .toNearestOrAwayFromZero).format(amount)
  }

  /// A free-trial note in the units a member actually reads, in `locale`'s
  /// language.
  ///
  /// Weeks are spoken as days — the stores record a trial as one week, but it
  /// is offered, and understood, as seven days. The count is a format argument
  /// of one catalog entry per unit, never spliced into English, so a language
  /// whose noun changes with the number gets a plural variation to fill in.
  nonisolated static func trialNote(count: Int, unit: PeriodUnit, locale: Locale) -> String {
    let bundle = Bundle.localized(for: locale)
    switch unit {
    case .day, .week:
      let days = unit == .week ? count * 7 : count
      return String(
        localized: "\(days)-day free trial",
        bundle: bundle,
        locale: locale,
        comment: "Paywall plan row. The placeholder is a number of days."
      )
    case .month:
      return String(
        localized: "\(count)-month free trial",
        bundle: bundle,
        locale: locale,
        comment: "Paywall plan row. The placeholder is a number of months."
      )
    case .year:
      return String(
        localized: "\(count)-year free trial",
        bundle: bundle,
        locale: locale,
        comment: "Paywall plan row. The placeholder is a number of years."
      )
    }
  }

  /// A trial length in days, or `nil` when the store expresses it in a unit
  /// whose day count isn't fixed. Callers price the trial off this, so a month
  /// must not be guessed at thirty.
  nonisolated static func trialDays(count: Int, unit: PeriodUnit) -> Int? {
    switch unit {
    case .day: return count
    case .week: return count * 7
    case .month, .year: return nil
    }
  }
}
