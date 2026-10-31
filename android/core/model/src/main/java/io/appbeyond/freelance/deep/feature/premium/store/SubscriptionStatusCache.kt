package io.appbeyond.freelance.deep.feature.premium.store

import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionState
import io.appbeyond.freelance.deep.shared.persistence.BlobStoring
import io.appbeyond.freelance.deep.shared.persistence.readOrNull
import io.appbeyond.freelance.deep.shared.persistence.writeQuietly

/**
 * The store's last-known entitlement, remembered across launches so the plan
 * chip opens on the right state rather than on "Checking…" while the store
 * is asked. Ported from
 * Deep/Deep/Features/Premium/Store/SubscriptionStatusCache.swift, with the
 * same spelling — `subscribed:<productId>` or `none` ([SubscriptionState.encode]).
 *
 * Its own type, apart from any one store, because two stores must never
 * encode it differently. The store's witness only: the server's answer is
 * [ReconciledPremiumAccess]'s, kept in a blob of its own.
 */
class SubscriptionStatusCache(private val blob: BlobStoring) {

  /** The remembered state, or null when nothing has been cached yet (or it is unreadable). */
  suspend fun load(): SubscriptionState? = SubscriptionState.decode(blob.readOrNull())

  /** Remembers [state]; [SubscriptionState.Unknown] is transient and never written. */
  suspend fun save(state: SubscriptionState) {
    val raw = SubscriptionState.encode(state) ?: return
    blob.writeQuietly(raw)
  }

  /** Forgets it — a signed-out device holds no one's membership. */
  suspend fun clear() {
    blob.writeQuietly(null)
  }
}
