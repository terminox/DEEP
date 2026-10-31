package io.appbeyond.freelance.deep.feature.premium.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.math.BigDecimal
import java.util.Locale
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The paywall's two claims about money: what a year saves, and what a member
 * will actually be charged. Both are derived from the plans the store hands
 * over — never written into the screen — so this is where they are pinned.
 *
 * Ported from Deep/DeepTests/PaywallPricingTests.swift and
 * SubscriptionPlanFormattingTests.swift. No expected price string is typed
 * out from mental arithmetic: a figure is checked against the same formatter
 * fed the amount it must round to, and against the cent a half-to-even
 * formatter would wrongly have quoted.
 */
class PaywallPricingTest {

  private val usLocale = Locale.US

  private fun decimal(value: String): BigDecimal = BigDecimal(value).stripTrailingZeros()

  private fun micros(value: String): Long = BigDecimal(value).movePointRight(6).longValueExact()

  private fun plan(period: SubscriptionPlan.Period, price: String, trialDays: Int? = null) = SubscriptionPlan(
    id = if (period == SubscriptionPlan.Period.Yearly) DeepProduct.YEARLY else DeepProduct.MONTHLY,
    period = period,
    displayPrice = "$$price",
    priceMicros = micros(price),
    currencyCode = "USD",
    freeTrialDays = trialDays,
    priceLocale = usLocale,
  )

  // MARK: - Savings

  @Test
  @DisplayName("A year against twelve months is the saving, truncated so a badge can only understate it")
  fun savingsAgainstTwelveMonths() {
    // 19.98 × 12 = 239.76; 91.98 is 61.6% less — and must not become 62%.
    assertEquals(61, PaywallPricing.yearlySavingsPercent(monthly = decimal("19.98"), yearly = decimal("91.98")))
  }

  @Test
  @DisplayName("Nothing to save means no badge")
  fun noSavingsMeansNoBadge() {
    assertNull(PaywallPricing.yearlySavingsPercent(monthly = decimal("10.00"), yearly = decimal("120.00")))
    assertNull(PaywallPricing.yearlySavingsPercent(monthly = decimal("10.00"), yearly = decimal("200.00")))
  }

  @Test
  @DisplayName("A saving that truncates to 0% draws no badge")
  fun noZeroPercentBadge() {
    // 120.00 a year of 10.00 months against 119.20: 0.67% saved, truncated to 0.
    assertNull(PaywallPricing.yearlySavingsPercent(monthly = decimal("10.00"), yearly = decimal("119.20")))
    // 118.80: exactly 1%.
    assertEquals(1, PaywallPricing.yearlySavingsPercent(monthly = decimal("10.00"), yearly = decimal("118.80")))
  }

  @Test
  @DisplayName("A free or missing price never divides by zero")
  fun zeroPriceIsSafe() {
    assertNull(PaywallPricing.yearlySavingsPercent(monthly = BigDecimal.ZERO, yearly = decimal("91.98")))
    assertNull(PaywallPricing.yearlySavingsPercent(monthly = decimal("19.98"), yearly = BigDecimal.ZERO))
  }

  @Test
  @DisplayName("A rounding-error saving isn't worth a badge")
  fun trivialSavingIsNotABadge() {
    // 0.04% — true, and not worth saying.
    assertNull(PaywallPricing.yearlySavingsPercent(monthly = decimal("10.00"), yearly = decimal("119.95")))
  }

  @Test
  @DisplayName("Savings read off a pair of plans match the raw numbers")
  fun savingsFromPlans() {
    val plans = listOf(plan(SubscriptionPlan.Period.Yearly, "91.98"), plan(SubscriptionPlan.Period.Monthly, "19.98"))
    assertEquals(61, PaywallPricing.yearlySavingsPercent(plans))
    // One plan alone has nothing to compare against.
    assertNull(PaywallPricing.yearlySavingsPercent(listOf(plans[0])))
    assertNull(PaywallPricing.yearlySavingsPercent(emptyList()))
  }

  // MARK: - Per month

  @Test
  @DisplayName("A year divides into twelve, and the currency decides the precision")
  fun perMonthLeavesRoundingToTheCurrency() {
    // Unrounded on purpose: a fixed two places would quote three-decimal
    // storefronts wrong.
    assertEquals(decimal("7.665"), PaywallPricing.perMonth(decimal("91.98")))
  }

  @Test
  @DisplayName("An exact half-cent rounds away from zero, not to even")
  fun moneyRoundsHalfAwayFromZero() {
    val quoted = SubscriptionPlanFormatting.money(PaywallPricing.perMonth(decimal("91.98")), "USD", usLocale)
    // 7.665 is a tie: the member reads the cent above it, as the row does.
    assertEquals(SubscriptionPlanFormatting.money(decimal("7.67"), "USD", usLocale), quoted)
    assertNotEquals(SubscriptionPlanFormatting.money(decimal("7.66"), "USD", usLocale), quoted)
    // The row's own figure comes through the same recipe.
    assertEquals(quoted, SubscriptionPlanFormatting.perMonthPrice(plan(SubscriptionPlan.Period.Yearly, "91.98"), Locale.ROOT))
  }

  @Test
  @DisplayName("A three-decimal currency keeps its third decimal")
  fun threeDecimalCurrencyIsNotTruncated() {
    // KD 10.000 a year is KD 0.833 a month, not KD 0.830 — twelve months must
    // still add up to the year.
    val perMonth = SubscriptionPlanFormatting.money(PaywallPricing.perMonth(decimal("10.000")), "KWD", Locale("en", "KW"))
    assertTrue("0.833" in perMonth, perMonth)
  }

  @Test
  @DisplayName("A currency without minor units shows none")
  fun zeroDecimalCurrency() {
    val yen = SubscriptionPlanFormatting.money(PaywallPricing.perMonth(decimal("12000")), "JPY", Locale.JAPAN)
    assertEquals(SubscriptionPlanFormatting.money(decimal("1000"), "JPY", Locale.JAPAN), yen)
    assertTrue('.' !in yen, yen)
  }

  @Test
  @DisplayName("The plan's own locale wins over the device's")
  fun planLocaleWins() {
    val yearly = plan(SubscriptionPlan.Period.Yearly, "91.98")
    assertEquals(
      SubscriptionPlanFormatting.perMonthPrice(yearly, usLocale),
      SubscriptionPlanFormatting.perMonthPrice(yearly, Locale("th", "TH")),
    )
  }

  @Test
  @DisplayName("Micros become an exact price")
  fun microsAreExact() {
    assertEquals(decimal("19.98"), plan(SubscriptionPlan.Period.Monthly, "19.98").price)
    assertEquals(0, BigDecimal("91.98").compareTo(plan(SubscriptionPlan.Period.Yearly, "91.98").price))
  }

  // MARK: - Billing facts

  @Test
  @DisplayName("A yearly plan with a trial states the trial, the month and the year")
  fun yearlyWithTrial() {
    assertEquals(
      PaywallPricing.BillingFacts.TrialThenYearly(trialDays = 7, perMonth = decimal("7.665"), total = decimal("91.98")),
      PaywallPricing.billingFacts(plan(SubscriptionPlan.Period.Yearly, "91.98", trialDays = 7)),
    )
  }

  @Test
  @DisplayName("A yearly plan without a trial promises no free days")
  fun yearlyWithoutTrial() {
    assertEquals(
      PaywallPricing.BillingFacts.Yearly(perMonth = decimal("7.665"), total = decimal("91.98")),
      PaywallPricing.billingFacts(plan(SubscriptionPlan.Period.Yearly, "91.98")),
    )
  }

  @Test
  @DisplayName("A monthly plan states its own price, not a twelfth of anything")
  fun monthlyFacts() {
    assertEquals(
      PaywallPricing.BillingFacts.TrialThenMonthly(trialDays = 7, total = decimal("19.98")),
      PaywallPricing.billingFacts(plan(SubscriptionPlan.Period.Monthly, "19.98", trialDays = 7)),
    )
    assertEquals(
      PaywallPricing.BillingFacts.Monthly(total = decimal("19.98")),
      PaywallPricing.billingFacts(plan(SubscriptionPlan.Period.Monthly, "19.98")),
    )
  }
}
