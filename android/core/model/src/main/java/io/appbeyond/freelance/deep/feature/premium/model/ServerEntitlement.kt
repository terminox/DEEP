package io.appbeyond.freelance.deep.feature.premium.model

import java.time.Instant

/**
 * The server's answer about DEEP Premium, narrowed to plain values.
 *
 * deep-api is the authority on access — it hears RevenueCat's webhooks and
 * withholds premium audio from anyone it doesn't count as a member — so its
 * answer is one of the two inputs [io.appbeyond.freelance.deep.feature.premium.store.ReconciledPremiumAccess]
 * reconciles. Ported from `ServerEntitlement` in
 * Deep/Deep/Features/Premium/Store/EntitlementFetching.swift; the wire shape
 * and its defaults live with the DTOs in `:app`.
 *
 * @property periodType NORMAL | TRIAL | INTRO …, as RevenueCat names it.
 * @property store APP_STORE | PLAY_STORE | PROMOTIONAL …, as RevenueCat names it.
 */
data class ServerEntitlement(
  val isActive: Boolean,
  val productId: String? = null,
  val expiresAt: Instant? = null,
  val willRenew: Boolean = false,
  val periodType: String? = null,
  val inGracePeriod: Boolean = false,
  val store: String? = null,
) {
  companion object {
    /** A member, for previews and tests. */
    val member = ServerEntitlement(isActive = true, productId = DeepProduct.YEARLY, willRenew = true, store = "PLAY_STORE")

    /** No membership, for previews and tests. */
    val lapsed = ServerEntitlement(isActive = false)
  }
}
