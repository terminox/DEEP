package io.appbeyond.freelance.deep.feature.premium.model

import java.math.BigDecimal
import java.math.MathContext
import java.math.RoundingMode
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

/**
 * The arithmetic behind the paywall's two claims — what the yearly plan
 * saves, and what a member will actually be charged.
 *
 * Ported from Deep/Deep/Features/Premium/Models/PaywallPricing.swift. Pure
 * and locale-free on purpose: it answers in numbers, and the paywall turns
 * those into a sentence. That split is what lets the money be tested without
 * a screen in the room, and it is why neither the savings badge nor the
 * billing line can ever be a hardcoded string.
 *
 * Money is [BigDecimal] built from Play's micros, never a float: a float
 * rounds 19.98 before any formatter sees it.
 */
object PaywallPricing {

  /**
   * What a year costs against twelve of the monthly plan, in whole percent —
   * 61 for $91.98 against $19.98 a month.
   *
   * Null when there is nothing honest to claim: a free or nonsensical price,
   * or a year that saves nothing, or less than half a percent. Truncated
   * rather than rounded, so a badge can only ever understate the saving.
   */
  fun yearlySavingsPercent(monthly: BigDecimal, yearly: BigDecimal): Int? {
    val year = monthly.multiply(MONTHS_PER_YEAR)
    if (monthly.signum() <= 0 || yearly.signum() <= 0 || year <= yearly) return null
    val saved = year.subtract(yearly).divide(year, MathContext.DECIMAL64)
    // Below half a percent there is no badge worth drawing.
    if (saved < MIN_SAVING) return null
    return saved.movePointRight(2).setScale(0, RoundingMode.DOWN).toInt()
  }

  /** The same, read off the two plans rather than two numbers. */
  fun yearlySavingsPercent(plans: List<SubscriptionPlan>): Int? {
    val monthly = plans.firstOrNull { it.period == SubscriptionPlan.Period.Monthly } ?: return null
    val yearly = plans.firstOrNull { it.period == SubscriptionPlan.Period.Yearly } ?: return null
    return yearlySavingsPercent(monthly = monthly.price, yearly = yearly.price)
  }

  /** What the money sentence has to say, as facts rather than as a sentence. */
  sealed interface BillingFacts {
    data class TrialThenYearly(val trialDays: Int, val perMonth: BigDecimal, val total: BigDecimal) : BillingFacts
    data class TrialThenMonthly(val trialDays: Int, val total: BigDecimal) : BillingFacts
    data class Yearly(val perMonth: BigDecimal, val total: BigDecimal) : BillingFacts
    data class Monthly(val total: BigDecimal) : BillingFacts
  }

  fun billingFacts(plan: SubscriptionPlan): BillingFacts {
    val days = plan.freeTrialDays
    return when (plan.period) {
      SubscriptionPlan.Period.Yearly ->
        if (days != null) {
          BillingFacts.TrialThenYearly(days, perMonth(plan.price), plan.price)
        } else {
          BillingFacts.Yearly(perMonth(plan.price), plan.price)
        }
      SubscriptionPlan.Period.Monthly ->
        if (days != null) BillingFacts.TrialThenMonthly(days, plan.price) else BillingFacts.Monthly(plan.price)
    }
  }

  /**
   * A yearly price divided into twelve, left unrounded.
   *
   * Rounding belongs to the currency, not to this: a fixed two places would
   * quote "KD 0.830 a month, billed yearly at KD 10.000" on the three-decimal
   * storefronts, where twelve months no longer add up to the year on a screen
   * whose whole job is stating the terms accurately.
   * [SubscriptionPlanFormatting.money] does the rounding, at the currency's
   * own precision. Trailing zeros are stripped so equal amounts compare equal.
   */
  fun perMonth(yearlyPrice: BigDecimal): BigDecimal =
    yearlyPrice.divide(MONTHS_PER_YEAR, MathContext.DECIMAL128).stripTrailingZeros()

  private val MONTHS_PER_YEAR = BigDecimal(12)
  private val MIN_SAVING = BigDecimal("0.005")
}

/**
 * The one recipe for turning a store's raw numbers into the money a paywall
 * quotes. Ported from Deep/Deep/Features/Premium/Models/SubscriptionPlanFormatting.swift.
 */
object SubscriptionPlanFormatting {

  /**
   * Money, rounded the way money rounds.
   *
   * Half away from zero, never Java's or Foundation's half-to-even: 91.98 / 12
   * is exactly 7.665, and half-to-even quotes $7.66 — a cent below the figure
   * the member is charged. The currency keeps its own precision, so a
   * three-decimal storefront (KWD, BHD) still renders three and yen renders
   * none.
   *
   * @param locale how the store spells money — [SubscriptionPlan.priceLocale]
   *   when the plan carries one, else the device's own, which is what Play
   *   formats `displayPrice` in.
   */
  fun money(amount: BigDecimal, currencyCode: String, locale: Locale): String {
    val currency = runCatching { Currency.getInstance(currencyCode) }.getOrNull()
      ?: return "${amount.setScale(2, RoundingMode.HALF_UP).toPlainString()} $currencyCode"
    val format = NumberFormat.getCurrencyInstance(locale)
    format.currency = currency
    val digits = currency.defaultFractionDigits.coerceAtLeast(0)
    format.minimumFractionDigits = digits
    format.maximumFractionDigits = digits
    format.roundingMode = RoundingMode.HALF_UP
    return format.format(amount)
  }

  /**
   * A yearly plan's price as a monthly figure, in the plan's own currency —
   * the one place that division and its rounding meet, so the plan row and
   * the billing sentence beneath it cannot disagree by a penny.
   */
  fun perMonthPrice(plan: SubscriptionPlan, deviceLocale: Locale): String =
    money(PaywallPricing.perMonth(plan.price), plan.currencyCode, plan.priceLocale ?: deviceLocale)
}
