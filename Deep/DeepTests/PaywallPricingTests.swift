import Testing
import Foundation
@testable import Deep

/// The paywall's two claims about money: what a year saves, and what a member
/// will actually be charged. Both are derived from the plans the store hands
/// over — never written into the screen — so this is where they are pinned.
@MainActor
struct PaywallPricingTests {
  private static let usd = Decimal.FormatStyle.Currency(
    code: "USD",
    locale: Locale(identifier: "en_US")
  )

  private static func decimal(_ string: String) -> Decimal {
    Decimal(string: string)!
  }

  private static func plan(
    period: SubscriptionPlan.Period,
    price: String,
    trialDays: Int? = nil
  ) -> SubscriptionPlan {
    let amount = decimal(price)
    return SubscriptionPlan(
      id: period == .yearly ? DeepProduct.yearly : DeepProduct.monthly,
      period: period,
      displayPrice: usd.format(amount),
      price: amount,
      currency: usd,
      freeTrialDays: trialDays
    )
  }

  // MARK: - Savings

  @Test("A year against twelve months is the saving")
  func savingsAgainstTwelveMonths() {
    // 19.98 × 12 = 239.76; 91.98 is 61.6% less.
    let saved = PaywallPricing.yearlySavings(
      monthly: Self.decimal("19.98"),
      yearly: Self.decimal("91.98")
    )
    #expect(saved == 0.61)
  }

  @Test("The saving is truncated, so a badge can only understate it")
  func savingsTruncate() {
    // 61.6% must not become 62%: a badge that rounds up overstates the offer.
    let saved = PaywallPricing.yearlySavings(
      monthly: Self.decimal("19.98"),
      yearly: Self.decimal("91.98")
    )
    #expect(saved.map { $0 < 0.616 } == true)
  }

  @Test("Nothing to save means no badge")
  func noSavingsMeansNoBadge() {
    let same = PaywallPricing.yearlySavings(
      monthly: Self.decimal("10.00"),
      yearly: Self.decimal("120.00")
    )
    #expect(same == nil)

    let worse = PaywallPricing.yearlySavings(
      monthly: Self.decimal("10.00"),
      yearly: Self.decimal("200.00")
    )
    #expect(worse == nil)
  }

  @Test("A free or missing monthly price never divides by zero")
  func zeroMonthlyIsSafe() {
    #expect(PaywallPricing.yearlySavings(monthly: 0, yearly: Self.decimal("91.98")) == nil)
    #expect(PaywallPricing.yearlySavings(monthly: Self.decimal("19.98"), yearly: 0) == nil)
  }

  @Test("A rounding-error saving isn't worth a badge")
  func trivialSavingIsNotABadge() {
    // 0.04% — true, and not worth saying.
    let saved = PaywallPricing.yearlySavings(
      monthly: Self.decimal("10.00"),
      yearly: Self.decimal("119.95")
    )
    #expect(saved == nil)
  }

  @Test("Savings read off a pair of plans match the raw numbers")
  func savingsFromPlans() {
    let plans = [
      Self.plan(period: .yearly, price: "91.98"),
      Self.plan(period: .monthly, price: "19.98"),
    ]
    #expect(PaywallPricing.yearlySavings(in: plans) == 0.61)
    // One plan alone has nothing to compare against.
    #expect(PaywallPricing.yearlySavings(in: [plans[0]]) == nil)
    #expect(PaywallPricing.yearlySavings(in: []) == nil)
  }

  // MARK: - Per month

  @Test("A year divides into twelve, and the currency decides the precision")
  func perMonthLeavesRoundingToTheCurrency() {
    // Unrounded on purpose: a fixed two places would quote three-decimal
    // storefronts wrong, and the currency formatter rounds correctly anyway.
    #expect(PaywallPricing.perMonth(Self.decimal("91.98")) == Self.decimal("7.665"))

    // What the member actually reads is the formatted figure, and the tie goes
    // up — the same recipe the compact per-month label uses, so a row and the
    // sentence beneath it can never disagree by a penny.
    #expect(
      SubscriptionPlanFormatting.money(
        PaywallPricing.perMonth(Self.decimal("91.98")),
        currency: Self.usd
      ) == "$7.67"
    )
    #expect(
      SubscriptionPlanFormatting.perMonthPrice(
        yearlyPrice: Self.decimal("91.98"),
        currency: Self.usd
      ) == "$7.67"
    )
  }

  @Test("A three-decimal currency keeps its third decimal")
  func threeDecimalCurrencyIsNotTruncated() {
    // KD 10.000 a year is KD 0.833 a month, not KD 0.830. Rounding to a fixed
    // two places on a Kuwaiti storefront would make twelve months stop adding
    // up to the year, on a screen whose whole job is stating the terms.
    let dinar = Decimal.FormatStyle.Currency(code: "KWD", locale: Locale(identifier: "en_KW"))
    let perMonth = SubscriptionPlanFormatting.perMonthPrice(
      yearlyPrice: Self.decimal("10.000"),
      currency: dinar
    )
    #expect(perMonth.contains("0.833"))
  }

  // MARK: - Billing facts

  @Test("A yearly plan with a trial states the trial, the month and the year")
  func yearlyWithTrial() {
    let facts = PaywallPricing.billingFacts(
      for: Self.plan(period: .yearly, price: "91.98", trialDays: 7)
    )
    #expect(facts == .trialThenYearly(
      trialDays: 7,
      perMonth: Self.decimal("7.665"),
      total: Self.decimal("91.98")
    ))
  }

  @Test("A yearly plan without a trial promises no free days")
  func yearlyWithoutTrial() {
    let facts = PaywallPricing.billingFacts(for: Self.plan(period: .yearly, price: "91.98"))
    #expect(facts == .yearly(perMonth: Self.decimal("7.665"), total: Self.decimal("91.98")))
  }

  @Test("A monthly plan states its own price, not a twelfth of anything")
  func monthlyFacts() {
    #expect(
      PaywallPricing.billingFacts(for: Self.plan(period: .monthly, price: "19.98", trialDays: 7))
        == .trialThenMonthly(trialDays: 7, total: Self.decimal("19.98"))
    )
    #expect(
      PaywallPricing.billingFacts(for: Self.plan(period: .monthly, price: "19.98"))
        == .monthly(total: Self.decimal("19.98"))
    )
  }

  // MARK: - Copy

  @Test("The billing sentence names the trial, the monthly figure and the year")
  func billingLineReadsAsMoney() {
    let line = PaywallCopy.billingLine(
      .trialThenYearly(trialDays: 7, perMonth: Self.decimal("7.67"), total: Self.decimal("91.98")),
      currency: Self.usd,
      locale: Locale(identifier: "en_US")
    )
    // "Cancel any time." gets its own line: it is the reassurance, not another
    // clause of the charge.
    #expect(line == "Free for 7 days, then $7.67 a month, billed yearly at $91.98.\nCancel any time.")
  }

  @Test("A monthly plan's sentence doesn't mention a year")
  func monthlyBillingLine() {
    let line = PaywallCopy.billingLine(
      .trialThenMonthly(trialDays: 7, total: Self.decimal("19.98")),
      currency: Self.usd,
      locale: Locale(identifier: "en_US")
    )
    #expect(line == "Free for 7 days, then $19.98 a month.\nCancel any time.")
  }

  @Test("The savings badge is a whole percent")
  func savingsBadgeCopy() {
    #expect(
      PaywallCopy.savingsBadge(fraction: 0.61, locale: Locale(identifier: "en_US")) == "Save 61%"
    )
  }

  @Test("Copy follows the locale it is handed, not the device's")
  func copyFollowsTheGivenLocale() {
    let thai = Locale(identifier: "th")

    // The whole point of passing a locale in: the in-app language picker sets
    // `\.locale` on the tree, and a preview can set it too. If this resolved
    // through `Bundle.main` alone, a Thai member would read English money.
    let subline = PaywallCopy.planSubline(
      for: Self.plan(period: .monthly, price: "19.98"),
      locale: thai
    )
    #expect(subline == "เรียกเก็บรายเดือน")

    let billing = PaywallCopy.billingLine(
      .trialThenYearly(trialDays: 7, perMonth: Self.decimal("7.67"), total: Self.decimal("91.98")),
      currency: Self.usd,
      locale: thai
    )
    #expect(billing.hasPrefix("ฟรี 7 วัน"))
    // The numbers survive the translation in the right order.
    #expect(billing.contains("$7.67"))
    #expect(billing.contains("$91.98"))

    #expect(PaywallCopy.savingsBadge(fraction: 0.61, locale: thai).hasPrefix("ประหยัด"))
  }

  @Test("The Thai legal sentence keeps its markdown links")
  func thaiLegalLineKeepsLinks() {
    let attributed = LegalCopy.invitation(.placeholder, locale: Locale(identifier: "th"))
    let links = attributed.runs.compactMap(\.link)
    // A translator dropping the [text](url) syntax would silently cost App
    // Review its two required links, in Thai only.
    #expect(links.contains(LegalLinks.placeholder.terms))
    #expect(links.contains(LegalLinks.placeholder.privacy))
  }

  @Test("Both legal sentences carry both links as links")
  func legalLineLinks() {
    // Onboarding and the paywall word it differently but must link the same
    // two documents, and neither may leave raw markdown on screen.
    for attributed in [
      LegalCopy.invitation(.placeholder, locale: Locale(identifier: "en_US")),
      LegalCopy.agreement(.placeholder, locale: Locale(identifier: "en_US")),
    ] {
      let links = attributed.runs.compactMap(\.link)
      #expect(links.contains(LegalLinks.placeholder.terms))
      #expect(links.contains(LegalLinks.placeholder.privacy))
      #expect(!String(attributed.characters).contains("]("))
    }
  }
}
