package io.appbeyond.freelance.deep.feature.premium.store

import android.app.Activity
import android.content.Context
import android.util.Log
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.DangerousSettings
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PackageType
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.PurchasesException
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitLogIn
import com.revenuecat.purchases.awaitLogOut
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.models.Period
import com.revenuecat.purchases.models.StoreProduct
import io.appbeyond.freelance.deep.feature.premium.model.DeepEntitlement
import io.appbeyond.freelance.deep.feature.premium.model.PurchaseOutcome
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionManagement
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionPlan
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionState
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * [SubscriptionStore] backed by RevenueCat — the app's one live purchase path.
 * Ported from Deep/Deep/Features/Premium/Store/RevenueCatSubscriptionStore.swift.
 *
 * RevenueCat owns purchase truth (Play Billing underneath, plus receipt
 * validation and the webhook that tells deep-api). This adapter only projects
 * it into the SDK-free types above it: the current offering's packages become
 * [SubscriptionPlan]s (annual → yearly, monthly → monthly, anything else
 * left out), the `deep_premium` entitlement becomes [SubscriptionState], and
 * where it is managed becomes [SubscriptionManagement].
 *
 * **Identity is the DEEP user id, never the email.** The account store hands
 * it over through [identify] on sign-up, login, launch, sign-out and
 * deletion. The SDK is configured with the last signed-in member's id, so a
 * returning member's launch never creates an anonymous customer first; a
 * purchase or restore re-identifies before it acts, and is refused with
 * [IdentityUnavailableException] rather than attached to an anonymous
 * RevenueCat id — re-homing anonymous purchases later is manual surgery.
 *
 * With no API key (every flavor but dev, until a Play Store app exists in the
 * RevenueCat project) the SDK is never configured and the store simply reads
 * [SubscriptionState.None] with no plans to offer.
 *
 * Differences from iOS:
 * - The SDK is configured on [scope] a beat after construction, not inside
 *   it: the last signed-in id lives in DataStore, which is never read on the
 *   main thread. Every call waits for that configuration first.
 * - The remembered status is read the same way; until it lands the status is
 *   [SubscriptionState.Unknown], which `PremiumAccess` counts for nothing.
 * - Trial eligibility needs no separate check: Play only returns the offers
 *   this account may still take, so the default option's free phase *is*
 *   the eligible trial.
 *
 * @param apiKey RevenueCat's public SDK key; null or blank leaves the SDK unconfigured.
 * @param lastKnownUserId the last signed-in DEEP user id, read from the
 *   account cache.
 * @param allowTestStoreInRelease RevenueCat shows an error and then crashes a
 *   *non-debuggable* build configured with a Test Store (`test_`) key. A dev
 *   debug build is debuggable, so this only matters for a minified dev
 *   release; it is true for the dev flavor alone, the only one that carries a
 *   test key (iOS needs the same switch for its Dev configuration).
 * @param verboseLogging the SDK's INFO logging, for dev builds.
 */
class RevenueCatSubscriptionStore(
  context: Context,
  apiKey: String?,
  private val cache: SubscriptionStatusCache,
  private val scope: CoroutineScope,
  lastKnownUserId: suspend () -> String?,
  allowTestStoreInRelease: Boolean = false,
  verboseLogging: Boolean = false,
) : SubscriptionStore {

  private val isConfigured = !apiKey.isNullOrBlank()

  // No store at all can never resolve Unknown, so a plan chip would read
  // "Checking…" forever. No key = not subscribed.
  private val _status = MutableStateFlow(if (isConfigured) SubscriptionState.Unknown else SubscriptionState.None)
  override val status: StateFlow<SubscriptionState> = _status.asStateFlow()

  private val _plans = MutableStateFlow<List<SubscriptionPlan>>(emptyList())
  override val plans: StateFlow<List<SubscriptionPlan>> = _plans.asStateFlow()

  private val _management = MutableStateFlow<SubscriptionManagement>(SubscriptionManagement.GooglePlay(null))
  override val management: StateFlow<SubscriptionManagement> = _management.asStateFlow()

  /** The configured SDK, or null when there is no key. Every call awaits it. */
  private val ready = CompletableDeferred<Purchases?>()

  /** The SDK's packages by [SubscriptionPlan.id], so a plan maps back to what is bought. */
  @Volatile private var packages: Map<String, Package> = emptyMap()

  /** The DEEP user id RevenueCat should speak for, as last reported. Null means signed out. */
  @Volatile private var expectedUserId: String? = null

  /** Whether [identify] has ever been called — its id then beats the cached one at configure time. */
  @Volatile private var identified = false

  /** Serialises log-ins and log-outs, so a fast sign-out and sign-in land in order. */
  private val identityLock = Mutex()

  /** Serialises status writes to [cache]; each writes the status current at that moment. */
  private val persistLock = Mutex()

  init {
    if (!isConfigured) {
      ready.complete(null)
    } else {
      val appContext = context.applicationContext
      scope.launch(Dispatchers.Main.immediate) {
        val remembered = cache.load()
        if (remembered != null && _status.value == SubscriptionState.Unknown) _status.value = remembered
        val userId = if (identified) expectedUserId else lastKnownUserId()
        if (!identified) expectedUserId = userId

        if (verboseLogging) Purchases.logLevel = LogLevel.INFO
        val settings = DangerousSettings(autoSyncPurchases = true)
        if (allowTestStoreInRelease) settings.forceAllowTestStoreInReleaseBuilds()
        val purchases = Purchases.configure(
          PurchasesConfiguration.Builder(appContext, apiKey.orEmpty())
            .appUserID(userId)
            .dangerousSettings(settings)
            .build(),
        )
        // Renewals, refunds, expiries and purchases made on another device
        // all arrive here — iOS's `customerInfoStream`.
        purchases.updatedCustomerInfoListener = UpdatedCustomerInfoListener { apply(it) }
        ready.complete(purchases)

        try {
          apply(purchases.awaitCustomerInfo())
        } catch (cancelled: CancellationException) {
          throw cancelled
        } catch (unreachable: PurchasesException) {
          // No remembered entitlement and no store: not subscribed. A real
          // entitlement corrects it on the next update or load.
          if (_status.value == SubscriptionState.Unknown) setStatus(SubscriptionState.None)
        }
      }
    }
  }

  // MARK: - SubscriptionStore

  override suspend fun loadPlans() {
    val purchases = ready.await() ?: return
    withContext(Dispatchers.Main.immediate) {
      try {
        val available = purchases.awaitOfferings().current?.availablePackages.orEmpty()
        val loaded = available.mapNotNull { pkg -> plan(pkg)?.let { it to pkg } }
        packages = loaded.associate { (plan, pkg) -> plan.id to pkg }
        _plans.value = SubscriptionPlan.canonicalOrder(loaded.map { it.first })
        apply(purchases.awaitCustomerInfo())
      } catch (cancelled: CancellationException) {
        // Walking away is not the store being unreachable: a screen closing
        // mid-query must not cache "not subscribed" for a real member.
        throw cancelled
      } catch (unreachable: PurchasesException) {
        // Offline or misconfigured — no plans; the paywall shows its gentle
        // fallback. With the store unreachable Unknown would never resolve.
        _plans.value = emptyList()
        if (_status.value == SubscriptionState.Unknown) setStatus(SubscriptionState.None)
      }
    }
  }

  override suspend fun purchase(activity: Activity, plan: SubscriptionPlan): PurchaseOutcome {
    val purchases = ready.await() ?: return PurchaseOutcome.Cancelled
    // Nothing loaded to buy. Nothing happened, so say nothing.
    val pkg = packages[plan.id] ?: return PurchaseOutcome.Cancelled
    return withContext(Dispatchers.Main.immediate) {
      ensureIdentified(purchases)
      try {
        val result = purchases.awaitPurchase(PurchaseParams.Builder(activity, pkg).build())
        apply(result.customerInfo)
        PurchaseOutcome.Purchased
      } catch (refused: PurchasesTransactionException) {
        when {
          refused.userCancelled || refused.code == PurchasesErrorCode.PurchaseCancelledError -> PurchaseOutcome.Cancelled
          refused.code == PurchasesErrorCode.PaymentPendingError -> PurchaseOutcome.Pending
          else -> throw refused
        }
      }
    }
  }

  override suspend fun restore() {
    val purchases = ready.await() ?: return
    withContext(Dispatchers.Main.immediate) {
      ensureIdentified(purchases)
      apply(purchases.awaitRestore())
    }
  }

  // MARK: - Identity

  /**
   * Points RevenueCat at this DEEP user, or back to anonymous on sign-out.
   *
   * The expectation moves at once, in call order; the SDK follows on
   * [scope], always towards the latest expectation, so a sign-out and the
   * next sign-in can never land the wrong way round. Failures are quiet: the
   * id is remembered, and [purchase] / [restore] retry the log-in before they
   * act, so a flaky network at sign-up can delay identification but never let
   * a purchase land anonymously.
   */
  fun identify(userId: String?) {
    expectedUserId = userId
    identified = true
    scope.launch { followIdentity() }
  }

  private suspend fun followIdentity() {
    val purchases = ready.await() ?: return
    identityLock.withLock {
      withContext(Dispatchers.Main.immediate) {
        val userId = expectedUserId
        if (userId != null) {
          if (purchases.appUserID == userId) return@withContext
          quietly("log in to RevenueCat") { apply(purchases.awaitLogIn(userId).customerInfo) }
        } else if (!purchases.isAnonymous) {
          // The previous member's entitlement must not linger on this device.
          if (!quietly("log out of RevenueCat") { apply(purchases.awaitLogOut()) }) setStatus(SubscriptionState.None)
        } else {
          setStatus(SubscriptionState.None)
        }
      }
    }
  }

  /** Makes sure RevenueCat speaks for the signed-in member before money moves. */
  private suspend fun ensureIdentified(purchases: Purchases) {
    val userId = expectedUserId ?: throw IdentityUnavailableException()
    if (purchases.appUserID == userId) return
    identityLock.withLock { apply(purchases.awaitLogIn(userId).customerInfo) }
  }

  // MARK: - Mapping

  private fun apply(info: CustomerInfo) {
    val entitlement = info.entitlements[DeepEntitlement.ID]
    setStatus(
      if (entitlement?.isActive == true) SubscriptionState.Subscribed(entitlement.productIdentifier) else SubscriptionState.None,
    )
    _management.value = if (entitlement == null) {
      SubscriptionManagement.GooglePlay(null)
    } else {
      SubscriptionManagement.of(
        store = entitlement.store.name,
        productId = entitlement.productIdentifier,
        managementUrl = info.managementURL?.toString(),
      )
    }
  }

  private fun setStatus(next: SubscriptionState) {
    _status.value = next
    scope.launch {
      withContext(NonCancellable) {
        persistLock.withLock { cache.save(_status.value) }
      }
    }
  }

  private suspend fun quietly(what: String, block: suspend () -> Unit): Boolean =
    try {
      block()
      true
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (failure: PurchasesException) {
      Log.w(TAG, "Could not $what.", failure)
      false
    }

  private companion object {
    const val TAG = "RevenueCatSubscription"

    /** A package as a plan, or null for a package type DEEP doesn't sell. */
    fun plan(pkg: Package): SubscriptionPlan? {
      val period = when (pkg.packageType) {
        PackageType.ANNUAL -> SubscriptionPlan.Period.Yearly
        PackageType.MONTHLY -> SubscriptionPlan.Period.Monthly
        else -> return null
      }
      val product = pkg.product
      return SubscriptionPlan(
        id = product.id,
        period = period,
        displayPrice = product.price.formatted,
        priceMicros = product.price.amountMicros,
        currencyCode = product.price.currencyCode,
        freeTrialDays = trialDays(product),
      )
    }

    /**
     * The free trial this account can still take, in days. Play only
     * returns offers the account is eligible for, so the default option's
     * free phase is already the honest answer — promising free days to
     * someone who can't have them is a lie and a policy rejection. Month- and
     * year-long trials promise no day count, as on iOS.
     */
    fun trialDays(product: StoreProduct): Int? {
      val period = product.defaultOption?.freePhase?.billingPeriod ?: return null
      return when (period.unit) {
        Period.Unit.DAY -> period.value
        Period.Unit.WEEK -> period.value * DAYS_PER_WEEK
        else -> null
      }
    }

    const val DAYS_PER_WEEK = 7
  }
}
