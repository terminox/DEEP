package io.appbeyond.freelance.deep.feature.premium.model

/**
 * What Settings' plan chip says, as a value the screen maps to its words.
 * Ported from `SettingsView.planLabel` (Deep/Deep/Features/Profile/SettingsView.swift).
 */
enum class PlanLabel {
  /** "DEEP Premium, yearly". */
  PremiumYearly,

  /** "DEEP Premium, monthly". */
  PremiumMonthly,

  /** "DEEP Premium" — another product, or a membership the store can't see. */
  Premium,

  /** "Free plan". */
  Free,

  /** "Checking…" — the store hasn't answered and nothing else says premium. */
  Checking,
  ;

  companion object {
    /**
     * The store's own answer first, since it names the plan. A membership the
     * store can't see — granted by the server, or carried by the server's
     * last answer while RevenueCat checks — is still one.
     */
    fun of(store: SubscriptionState, hasPremium: Boolean): PlanLabel = when (store) {
      is SubscriptionState.Subscribed -> when (DeepProduct.planOf(store.productId)) {
        SubscriptionPlan.Period.Yearly -> PremiumYearly
        SubscriptionPlan.Period.Monthly -> PremiumMonthly
        null -> Premium
      }
      SubscriptionState.None, SubscriptionState.Unknown -> when {
        hasPremium -> Premium
        store == SubscriptionState.None -> Free
        else -> Checking
      }
    }
  }
}

/**
 * Where a member goes to change or cancel DEEP Premium. Ported from
 * `SubscriptionManagement` (Deep/Deep/Features/Premium/Store/SubscriptionStore.swift),
 * with Google Play standing where the App Store's own sheet stands on iOS.
 */
sealed interface SubscriptionManagement {

  /**
   * Bought through Google Play: Play's subscriptions page, opened on this
   * subscription when its id is known.
   */
  data class GooglePlay(val subscriptionId: String?) : SubscriptionManagement

  /** Bought somewhere else (the App Store, the web): the page that manages it. */
  data class Web(val url: String) : SubscriptionManagement

  /** The address to open; [packageName] is this build's application id. */
  fun url(packageName: String): String = when (this) {
    is Web -> url
    is GooglePlay ->
      if (subscriptionId == null) {
        PLAY_SUBSCRIPTIONS
      } else {
        "$PLAY_SUBSCRIPTIONS?sku=$subscriptionId&package=$packageName"
      }
  }

  companion object {
    /** Play's own list of the account's subscriptions. */
    const val PLAY_SUBSCRIPTIONS = "https://play.google.com/store/account/subscriptions"

    /** Apple's own page for the account's subscriptions — a membership bought on an iPhone. */
    const val APP_STORE_SUBSCRIPTIONS = "https://apps.apple.com/account/subscriptions"

    /** The `store` values RevenueCat (and deep-api) give each kind of purchase. */
    const val PLAY_STORE = "PLAY_STORE"
    const val APP_STORE = "APP_STORE"
    const val MAC_APP_STORE = "MAC_APP_STORE"

    /** A membership granted rather than bought — nothing anywhere to manage. */
    const val PROMOTIONAL = "PROMOTIONAL"

    /**
     * The rule, by where the membership came from: a Play purchase on Play's
     * page for that subscription; an App Store one on Apple's page (a member
     * who bought on an iPhone and signs in here); a granted one nowhere —
     * null, and Settings offers no Manage row; anything else at the URL
     * RevenueCat names for it, and failing that Play's general page.
     *
     * @param store the entitlement's store, as RevenueCat or the server spells it.
     * @param productId the entitlement's product, in either id shape.
     * @param managementUrl RevenueCat's `managementURL`, if it gave one.
     */
    fun of(store: String?, productId: String?, managementUrl: String?): SubscriptionManagement? = when (store) {
      PLAY_STORE -> GooglePlay(productId?.let(DeepProduct::subscriptionId))
      APP_STORE, MAC_APP_STORE -> Web(APP_STORE_SUBSCRIPTIONS)
      PROMOTIONAL -> null
      else -> managementUrl?.let(::Web) ?: GooglePlay(null)
    }

    /**
     * Where Settings sends a member, or null when there is nothing to manage:
     * the store's own answer when the store sees the membership; otherwise —
     * a membership only the server knows about (granted, bought on another
     * platform, or any membership in a build with no store) — the server's
     * account of where it came from, still offered RevenueCat's page.
     */
    fun forMember(
      store: SubscriptionState,
      storeManagement: SubscriptionManagement?,
      server: ServerEntitlement?,
    ): SubscriptionManagement? {
      if (store is SubscriptionState.Subscribed || server?.isActive != true) return storeManagement
      return of(server.store, server.productId, (storeManagement as? Web)?.url)
    }
  }
}
