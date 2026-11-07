package io.appbeyond.freelance.deep.feature.premium

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.feature.premium.store.FakePremiumAccess
import io.appbeyond.freelance.deep.feature.premium.store.PremiumAccess
import io.appbeyond.freelance.deep.feature.premium.store.PreviewSubscriptionStore
import io.appbeyond.freelance.deep.feature.premium.store.SubscriptionStore

/**
 * The one DEEP Premium answer, for every screen that draws a lock — iOS's
 * `@Environment(\.premiumAccess)`. `MainActivity` provides the live
 * `ReconciledPremiumAccess` at the root.
 *
 * A composition local rather than a parameter, unlike most of this app's
 * dependencies, for the reason iOS uses the environment: a lock is drawn by
 * leaves several layers down (a tile inside a carousel inside a shelf inside
 * a home), and threading one answer through every layer between would put
 * it in a dozen signatures that never read it. The default reads as the free
 * plan, so previews are hermetic.
 *
 * Static: the instance never changes for the life of the process; what
 * changes is read through its flows ([rememberHasPremium],
 * [rememberContentEpoch]).
 */
val LocalPremiumAccess = staticCompositionLocalOf<PremiumAccess> { FakePremiumAccess(hasPremium = false) }

/**
 * The purchasing store, for Settings' membership rows (and the paywall).
 * The default buys nothing and reads as "not subscribed".
 */
val LocalSubscriptionStore = staticCompositionLocalOf<SubscriptionStore> { PreviewSubscriptionStore() }

/** Whether this listener has DEEP Premium — the one input every `PremiumGate` call takes. */
@Composable
fun rememberHasPremium(): Boolean {
  val hasPremium by LocalPremiumAccess.current.hasPremium.collectAsStateWithLifecycle()
  return hasPremium
}

/**
 * The premium content epoch: content fetched under an older one may carry
 * stale verdicts, so a screen that fetched content keys its loading on this.
 */
@Composable
fun rememberContentEpoch(): Int {
  val epoch by LocalPremiumAccess.current.contentEpoch.collectAsStateWithLifecycle()
  return epoch
}
