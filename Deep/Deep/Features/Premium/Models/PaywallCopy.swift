import Foundation

/// Turns the paywall's numbers into its sentences.
///
/// The locale arrives as an argument rather than being read from the ambient
/// language: this copy is assembled inside a view body, where `\.locale` is what
/// the in-app picker sets — and what a Thai preview can set. Taking it in also
/// keeps every function here pure, and therefore testable.
enum PaywallCopy {
  /// "Save 61%".
  static func savingsBadge(fraction: Double, locale: Locale) -> String {
    let percent = fraction.formatted(
      .percent.precision(.fractionLength(0)).locale(locale)
    )
    return String(
      localized: "Save \(percent)",
      bundle: .localized(for: locale),
      locale: locale,
      comment: "Badge on the yearly plan row. The placeholder is a percentage."
    )
  }

  /// The money sentence under the plans — what is charged, and when.
  ///
  /// Apple requires the price, the billing period and the renewal terms to be
  /// stated on the paywall itself, so this sentence is not decoration.
  static func billingLine(
    _ facts: PaywallPricing.BillingFacts,
    currency: Decimal.FormatStyle.Currency,
    locale: Locale
  ) -> String {
    let bundle = Bundle.localized(for: locale)
    // Every figure goes through the one money recipe, so the sentence can't
    // quote a different cent from the row above it.
    func money(_ amount: Decimal) -> String {
      SubscriptionPlanFormatting.money(amount, currency: currency)
    }
    switch facts {
    case .trialThenYearly(let days, let perMonth, let total):
      return String(
        localized: "Free for \(days) days, then \(money(perMonth)) a month, billed yearly at \(money(total)).\nCancel any time.",
        bundle: bundle,
        locale: locale,
        comment: "Paywall billing terms for a yearly plan with a free trial."
      )
    case .trialThenMonthly(let days, let total):
      return String(
        localized: "Free for \(days) days, then \(money(total)) a month.\nCancel any time.",
        bundle: bundle,
        locale: locale,
        comment: "Paywall billing terms for a monthly plan with a free trial."
      )
    case .yearly(let perMonth, let total):
      return String(
        localized: "\(money(perMonth)) a month, billed yearly at \(money(total)).\nCancel any time.",
        bundle: bundle,
        locale: locale,
        comment: "Paywall billing terms for a yearly plan with no free trial."
      )
    case .monthly(let total):
      return String(
        localized: "\(money(total)) a month.\nCancel any time.",
        bundle: bundle,
        locale: locale,
        comment: "Paywall billing terms for a monthly plan with no free trial."
      )
    }
  }

  /// The label under a plan's name: what a year works out to per month, or the
  /// plain billing period for a plan that is already monthly.
  static func planSubline(for plan: SubscriptionPlan, locale: Locale) -> String {
    let bundle = Bundle.localized(for: locale)
    switch plan.period {
    case .monthly:
      // Its per-month figure is its price, which sits alongside already.
      return String(localized: "Billed monthly", bundle: bundle, locale: locale)
    case .yearly:
      let perMonth = SubscriptionPlanFormatting.perMonthPrice(
        yearlyPrice: plan.price,
        currency: plan.currency
      )
      return String(
        localized: "\(perMonth) a month",
        bundle: bundle,
        locale: locale,
        comment: "Subline on the yearly plan row. The placeholder is a price."
      )
    }
  }

}

extension Bundle {
  /// The compiled `.lproj` for a given locale — the view-environment twin of
  /// `Bundle.app`.
  ///
  /// Copy assembled inside a body must follow `\.locale`, which is what the
  /// in-app language picker sets on the tree (and the only thing a preview can
  /// set). `Bundle.app` follows the stored pick instead, which is right for
  /// copy resolved outside a view and wrong here — it would leave a Thai
  /// preview rendering half in English.
  static func localized(for locale: Locale) -> Bundle {
    guard let code = locale.language.languageCode?.identifier,
          let path = Bundle.main.path(forResource: code, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return .main }
    return bundle
  }
}
