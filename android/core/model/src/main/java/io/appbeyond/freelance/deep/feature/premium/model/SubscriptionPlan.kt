package io.appbeyond.freelance.deep.feature.premium.model

import java.math.BigDecimal
import java.util.Locale

/**
 * A purchasable DEEP Premium plan, projected from a RevenueCat `Package` so
 * nothing above the store ever depends on the SDK.
 *
 * Ported from Deep/Deep/Features/Premium/Models/SubscriptionPlan.swift. It
 * carries the store's own string ([displayPrice]) and the numbers behind it
 * ([priceMicros], [currencyCode], [freeTrialDays]): the paywall shows the
 * string and reasons about the numbers — a savings badge or a billing
 * sentence has to be derived, never hardcoded. The derived labels themselves
 * (per month, trial note) belong to the paywall that shows them.
 *
 * @property id the store product id, e.g. `deep.pro.yearly` (Test Store) or
 *   `deep.pro.yearly:yearly` (Play).
 * @property displayPrice the price as the store formats it, e.g. "$91.98".
 * @property priceMicros the same price in millionths of [currencyCode], the
 *   way Play reports it — exact, so no float ever rounds a cent away.
 * @property freeTrialDays the free trial this member can still take, in
 *   days; null promises nothing.
 * @property priceLocale how this store spells money, when the store says so
 *   (the fixtures pin US English, as iOS's do). Null — Play, which reports
 *   only a currency — formats derived figures in the device's own locale,
 *   the one Play formatted [displayPrice] in.
 */
data class SubscriptionPlan(
  val id: String,
  val period: Period,
  val displayPrice: String,
  val priceMicros: Long,
  val currencyCode: String,
  val freeTrialDays: Int? = null,
  val priceLocale: Locale? = null,
) {
  /** [priceMicros] as an exact amount of [currencyCode], for arithmetic the label can't do. */
  val price: BigDecimal get() = BigDecimal.valueOf(priceMicros, MICROS_SCALE).stripTrailingZeros()

  enum class Period {
    Monthly,
    Yearly,
  }

  companion object {
    private const val MICROS_SCALE = 6

    /** Yearly first, whatever order the offering lists them in — the paywall preselects the first. */
    fun canonicalOrder(plans: List<SubscriptionPlan>): List<SubscriptionPlan> =
      plans.filter { it.period == Period.Yearly } + plans.filter { it.period == Period.Monthly }
  }
}

/**
 * What came of a purchase attempt. Backing out and a payment awaiting
 * approval are ordinary outcomes, not errors: the paywall stands down in
 * silence for one and says something quiet for the other. A thrown error
 * means the purchase genuinely failed.
 */
enum class PurchaseOutcome {
  Purchased,
  Cancelled,
  Pending,
}
