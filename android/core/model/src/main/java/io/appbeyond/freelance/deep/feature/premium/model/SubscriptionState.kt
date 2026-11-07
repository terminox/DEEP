package io.appbeyond.freelance.deep.feature.premium.model

/**
 * What the purchasing store says about DEEP Premium. [Unknown] until the
 * store has been asked; anything other than [Subscribed] reads as "not yet a
 * member" to the store.
 *
 * Ported from `SubscriptionState` in
 * Deep/Deep/Features/Premium/Models/SubscriptionPlan.swift. Store-only on
 * purpose: the server's answer lives in [io.appbeyond.freelance.deep.feature.premium.store.PremiumAccess],
 * and only there do the two meet.
 */
sealed interface SubscriptionState {
  data object Unknown : SubscriptionState

  data object None : SubscriptionState

  /**
   * An active `deep_premium` entitlement. [productId] is the store's own
   * identifier — `deep.pro.yearly` from the Test Store, or Play's
   * `subscriptionId:basePlanId` shape; [DeepProduct.planOf] reads either.
   */
  data class Subscribed(val productId: String) : SubscriptionState

  val isSubscribed: Boolean get() = this is Subscribed

  companion object {
    private const val NONE = "none"
    private const val SUBSCRIBED_PREFIX = "subscribed:"

    /**
     * The remembered state as iOS's `SubscriptionStatusCache` spells it —
     * `subscribed:<productId>` or `none` — so the two platforms read one
     * vocabulary. [Unknown] is transient and never encoded (null).
     */
    fun encode(state: SubscriptionState): String? = when (state) {
      is Subscribed -> SUBSCRIBED_PREFIX + state.productId
      None -> NONE
      Unknown -> null
    }

    /** The inverse of [encode]; null for anything it never wrote. */
    fun decode(raw: String?): SubscriptionState? = when {
      raw == null -> null
      raw == NONE -> None
      raw.startsWith(SUBSCRIBED_PREFIX) -> Subscribed(raw.removePrefix(SUBSCRIBED_PREFIX))
      else -> null
    }
  }
}

/**
 * Product identifiers for DEEP Premium — the same ids in the RevenueCat Test
 * Store, App Store Connect and Play Console. Unchanged from the product's
 * former name: a store product id can never be reused.
 *
 * Ported from `DeepProduct` in Deep/Deep/Features/Premium/Store/SubscriptionStore.swift.
 */
object DeepProduct {
  const val MONTHLY = "deep.pro.monthly"
  const val YEARLY = "deep.pro.yearly"

  /**
   * The plan a product id names, or null for any other product. Play spells
   * a subscription product `subscriptionId:basePlanId`; only the part before
   * the colon names the plan.
   */
  fun planOf(productId: String): SubscriptionPlan.Period? = when (subscriptionId(productId)) {
    YEARLY -> SubscriptionPlan.Period.Yearly
    MONTHLY -> SubscriptionPlan.Period.Monthly
    else -> null
  }

  /** The subscription half of a Play product id — the whole id anywhere else. */
  fun subscriptionId(productId: String): String = productId.substringBefore(':')
}

/**
 * The RevenueCat entitlement both products unlock — the DEEP Premium
 * project's identifier, and the one deep-api's webhook reads
 * (`REVENUECAT_ENTITLEMENT_ID`).
 */
object DeepEntitlement {
  const val ID = "deep_premium"
}
