package io.appbeyond.freelance.deep.feature.premium.model

import io.appbeyond.freelance.deep.feature.premium.store.ReconciledPremiumAccess
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Content stamped with the premium epoch it was fetched under — what lets a
 * screen rebuilt after the answer moved (a tab that wasn't showing) see that
 * it holds stale verdicts, where a reload keyed only on the epoch changing
 * would have taken the new epoch for the one it arrived on.
 */
class KeptContentTest {

  @Test
  @DisplayName("A copy fetched before the answer moved is stale; one fetched after is not")
  fun staleness() {
    val copy = KeptContent(owner = "u1", epoch = 3, value = "shelves")
    assertFalse(copy.isStale(currentEpoch = 3))
    assertTrue(copy.isStale(currentEpoch = 4))
  }

  @Test
  @DisplayName("The freshest copy wins, whichever it is; nothing kept is nothing")
  fun freshest() {
    val older = KeptContent("u1", 1, "a")
    val newer = KeptContent("u1", 2, "b")
    assertEquals(newer, KeptContent.freshest(older, newer))
    assertEquals(newer, KeptContent.freshest(newer, null, older))
    assertNull(KeptContent.freshest<String>(null, null))
  }

  @Test
  @DisplayName("Server membership arriving over a store purchase leaves earlier content stale")
  fun purchaseThenServerGrantStalesContent() = runTest {
    // The QA path: a store purchase flips hasPremium, content is fetched
    // under that epoch (the server still withholding), then the server
    // agrees — no flip, but the epoch moves, so that content is stale.
    val store = MutableStateFlow<SubscriptionState>(SubscriptionState.None)
    val access = ReconciledPremiumAccess(store, fetcher = null, blob = InMemoryBlobStore(), scope = backgroundScope)
    runCurrent()
    access.adopt(ServerEntitlement.lapsed)
    store.value = SubscriptionState.Subscribed(DeepProduct.YEARLY)
    runCurrent()
    val shelves = KeptContent("u1", access.contentEpoch.value, "withheld")

    access.adopt(ServerEntitlement.member)

    assertTrue(access.hasPremium.value)
    assertTrue(shelves.isStale(access.contentEpoch.value))
  }
}
