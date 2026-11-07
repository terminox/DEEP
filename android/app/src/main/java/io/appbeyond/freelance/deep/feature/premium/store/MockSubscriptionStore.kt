package io.appbeyond.freelance.deep.feature.premium.store

import android.app.Activity
import io.appbeyond.freelance.deep.feature.premium.model.DeepProduct
import io.appbeyond.freelance.deep.feature.premium.model.PurchaseOutcome
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionManagement
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionPlan
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionState
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * In-memory [SubscriptionStore] for previews, tests and the emulator — plans
 * in code, no Play Billing, no network. Ported from
 * Deep/Deep/Features/Premium/Store/MockSubscriptionStore.swift.
 *
 * Its two behaviour knobs exist so every paywall state can be staged: a store
 * that never answers, one that can't be reached, a purchase that fails, one
 * awaiting approval.
 *
 * **Never in a shipping build.** iOS wraps it in `#if DEBUG`; here it is
 * referenced only from previews and from the debug-only launch switch in
 * `AppDependencies` (`BuildConfig.DEBUG`, a compile-time `false` in release),
 * so R8 drops it from every release build — checked against the minified
 * prod APK's dex.
 */
class MockSubscriptionStore(
  status: SubscriptionState = SubscriptionState.None,
  plans: List<SubscriptionPlan> = samplePlans,
  private val loading: Loading = Loading.Succeeds,
  private val purchasing: Purchasing = Purchasing.Succeeds,
) : SubscriptionStore {

  /** What [loadPlans] does. [Hangs] never returns, parking the caller in its loading state. */
  enum class Loading { Succeeds, Hangs, Fails }

  /** What [purchase] does. */
  enum class Purchasing { Succeeds, Cancels, Pends, Fails }

  class Failure : Exception("The mock store was told to fail.")

  override val isAvailable: Boolean = true

  private val _status = MutableStateFlow(status)
  override val status: StateFlow<SubscriptionState> = _status.asStateFlow()

  /** What a successful load produces — held apart so a fixture that starts empty still ends with its plans. */
  private val catalogue = plans

  private val _plans = MutableStateFlow(if (loading == Loading.Succeeds) plans else emptyList())
  override val plans: StateFlow<List<SubscriptionPlan>> = _plans.asStateFlow()

  override val management: StateFlow<SubscriptionManagement?> =
    MutableStateFlow<SubscriptionManagement?>(SubscriptionManagement.GooglePlay(DeepProduct.YEARLY)).asStateFlow()

  override suspend fun loadPlans() {
    when (loading) {
      Loading.Succeeds -> _plans.value = catalogue
      Loading.Hangs -> {
        _plans.value = emptyList()
        // Park. A preview lives and dies inside this wait, holding the skeleton.
        awaitCancellation()
      }
      // An unreachable store reports nothing, exactly as the real one does.
      Loading.Fails -> _plans.value = emptyList()
    }
  }

  override suspend fun purchase(activity: Activity, plan: SubscriptionPlan): PurchaseOutcome =
    when (purchasing) {
      Purchasing.Succeeds -> {
        _status.value = SubscriptionState.Subscribed(plan.id)
        PurchaseOutcome.Purchased
      }
      Purchasing.Cancels -> PurchaseOutcome.Cancelled
      Purchasing.Pends -> PurchaseOutcome.Pending
      Purchasing.Fails -> throw Failure()
    }

  override suspend fun restore() = Unit

  companion object {
    /** The fixtures are priced in US dollars, as iOS's are, so a preview renders the same money anywhere. */
    private const val CURRENCY = "USD"

    private fun plan(id: String, period: SubscriptionPlan.Period, display: String, micros: Long, trialDays: Int?) =
      SubscriptionPlan(
        id = id,
        period = period,
        displayPrice = display,
        priceMicros = micros,
        currencyCode = CURRENCY,
        freeTrialDays = trialDays,
      )

    /** $91.98 a year and $19.98 a month, each with a seven-day trial — iOS's `samplePlans`. */
    val samplePlans: List<SubscriptionPlan> = listOf(
      plan(DeepProduct.YEARLY, SubscriptionPlan.Period.Yearly, "$91.98", 91_980_000L, trialDays = 7),
      plan(DeepProduct.MONTHLY, SubscriptionPlan.Period.Monthly, "$19.98", 19_980_000L, trialDays = 7),
    )

    /** A trial on the year, none on the month — the paywall must put the claim on the row that owns it. */
    val mixedTrialPlans: List<SubscriptionPlan> = listOf(
      plan(DeepProduct.YEARLY, SubscriptionPlan.Period.Yearly, "$91.98", 91_980_000L, trialDays = 7),
      plan(DeepProduct.MONTHLY, SubscriptionPlan.Period.Monthly, "$19.98", 19_980_000L, trialDays = null),
    )

    val free: MockSubscriptionStore get() = MockSubscriptionStore(SubscriptionState.None)

    val subscribed: MockSubscriptionStore get() = MockSubscriptionStore(SubscriptionState.Subscribed(DeepProduct.YEARLY))

    /** Only one plan carries a trial. */
    val mixedTrials: MockSubscriptionStore get() = MockSubscriptionStore(plans = mixedTrialPlans)

    /** A store that never answers — the paywall holds its breathing skeleton. */
    val loadingPlans: MockSubscriptionStore get() = MockSubscriptionStore(plans = emptyList(), loading = Loading.Hangs)

    /** A store that can't be reached — the paywall shows its quiet note. */
    val unreachable: MockSubscriptionStore get() = MockSubscriptionStore(plans = emptyList(), loading = Loading.Fails)

    val purchaseFails: MockSubscriptionStore get() = MockSubscriptionStore(purchasing = Purchasing.Fails)
  }
}
