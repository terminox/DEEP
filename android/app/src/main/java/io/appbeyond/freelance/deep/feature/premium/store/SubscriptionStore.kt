package io.appbeyond.freelance.deep.feature.premium.store

import android.app.Activity
import io.appbeyond.freelance.deep.feature.premium.model.PurchaseOutcome
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionManagement
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionPlan
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * DEEP Premium's purchasing surface. Screens depend on this, never on
 * RevenueCat directly, so the paywall and Settings preview against
 * [PreviewSubscriptionStore] (or the debug [MockSubscriptionStore]) offline.
 * [RevenueCatSubscriptionStore] is the one live conformer.
 *
 * Ported from Deep/Deep/Features/Premium/Store/SubscriptionStore.swift. Purely
 * about purchasing: whether someone *has* DEEP Premium is
 * [io.appbeyond.freelance.deep.feature.premium.store.PremiumAccess]'s answer,
 * which reads [status] as one of its inputs.
 */
interface SubscriptionStore {

  /**
   * Whether this build can reach a store at all. False in every flavor that
   * carries no RevenueCat key yet (staging, pilot and prod until a Play Store
   * app exists): nothing can be bought or restored, and the screens say so
   * rather than pretend.
   */
  val isAvailable: Boolean

  /** What the store says about the `deep_premium` entitlement. */
  val status: StateFlow<SubscriptionState>

  /** The plans the current offering sells, yearly first; empty until [loadPlans] finds some. */
  val plans: StateFlow<List<SubscriptionPlan>>

  /**
   * Where this member manages DEEP Premium — told as plainly as Settings
   * needs it, so no screen ever touches the purchasing SDK's own types. Null
   * when there is nothing to manage (a granted membership).
   */
  val management: StateFlow<SubscriptionManagement?>

  /** Fetches the plans from the store. Safe to call repeatedly. */
  suspend fun loadPlans()

  /**
   * Buys [plan], showing the store's own sheet over [activity]. Backing out
   * and a payment awaiting approval come back as outcomes; a genuine failure
   * throws.
   */
  suspend fun purchase(activity: Activity, plan: SubscriptionPlan): PurchaseOutcome

  /**
   * Asks the store for purchases this account already made. Throws when the
   * store can't be reached — [StoreUnavailableException] when this build has
   * no store at all.
   */
  suspend fun restore()
}

/**
 * The member tried to buy or restore before their DEEP account id reached the
 * store — a purchase now would land on an anonymous customer, which is manual
 * surgery to re-home later.
 */
class IdentityUnavailableException : IllegalStateException("No DEEP member is signed in to buy for.")

/**
 * This build has no store to ask ([SubscriptionStore.isAvailable] is false).
 * A restore that silently did nothing would read as "Restored" with nothing
 * restored; failing says what is true — Google Play can't be reached from here.
 */
class StoreUnavailableException : IllegalStateException("This build has no store to reach.")

/**
 * A tiny always-available stand-in: the default the composition locals hand
 * a preview, and what a build without a store reads as. Reads [status] as
 * given, offers nothing, buys nothing.
 *
 * Kept apart from [MockSubscriptionStore] (iOS's `PreviewSubscriptionStore`
 * beside its DEBUG-only mock) so the locals' default never pulls the mock's
 * fixtures into a release build.
 */
class PreviewSubscriptionStore(
  status: SubscriptionState = SubscriptionState.None,
  override val isAvailable: Boolean = true,
) : SubscriptionStore {
  override val status: StateFlow<SubscriptionState> = MutableStateFlow(status).asStateFlow()
  override val plans: StateFlow<List<SubscriptionPlan>> = MutableStateFlow(emptyList<SubscriptionPlan>()).asStateFlow()
  override val management: StateFlow<SubscriptionManagement?> =
    MutableStateFlow<SubscriptionManagement?>(SubscriptionManagement.GooglePlay(null)).asStateFlow()

  override suspend fun loadPlans() = Unit

  override suspend fun purchase(activity: Activity, plan: SubscriptionPlan): PurchaseOutcome = PurchaseOutcome.Cancelled

  override suspend fun restore() = Unit
}
