package io.appbeyond.freelance.deep.feature.premium.store

import io.appbeyond.freelance.deep.feature.premium.model.DeepProduct
import io.appbeyond.freelance.deep.feature.premium.model.ServerEntitlement
import io.appbeyond.freelance.deep.feature.premium.model.SubscriptionState
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/PremiumAccessTests.swift: the union grants, a
 * purchase unlocks at once and is confirmed on a ladder, the flip counter
 * moves once per flip, and nothing regresses to locked offline.
 *
 * Every test runs on virtual time: the grace window and the ladder's waits
 * cost nothing, and `now` reads the scheduler's clock.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ReconciledPremiumAccessTest {

  /** Scripted [EntitlementFetching]: each call answers with the next result, repeating the last. */
  private class ScriptedFetcher(
    var answers: List<Result<ServerEntitlement?>> = listOf(Result.success(null)),
    var refreshAnswer: Result<ServerEntitlement?> = Result.failure(Unreachable()),
  ) : EntitlementFetching {
    class Unreachable : Exception("unreachable")

    var currentCalls = 0
      private set
    var refreshCalls = 0
      private set

    /** When set, `currentEntitlement` waits for it before answering. */
    var gate: CompletableDeferred<Unit>? = null

    override suspend fun currentEntitlement(): ServerEntitlement? {
      val answer = answers.getOrElse(currentCalls) { answers.last() }
      currentCalls += 1
      gate?.await()
      return answer.getOrThrow()
    }

    override suspend fun refreshEntitlement(): ServerEntitlement? {
      refreshCalls += 1
      return refreshAnswer.getOrThrow()
    }
  }

  private fun TestScope.access(
    store: SubscriptionState = SubscriptionState.None,
    fetcher: EntitlementFetching? = null,
    blob: InMemoryBlobStore = InMemoryBlobStore(),
    storeFlow: MutableStateFlow<SubscriptionState> = MutableStateFlow(store),
  ): ReconciledPremiumAccess {
    val access = ReconciledPremiumAccess(
      storeStatus = storeFlow,
      fetcher = fetcher,
      blob = blob,
      scope = backgroundScope,
      now = { testScheduler.currentTime },
    )
    runCurrent()
    return access
  }

  // MARK: - Truth table

  @Test
  @DisplayName("Server no, store yes: unlocked")
  fun serverNoStoreYes() = runTest {
    val access = access(store = SubscriptionState.Subscribed(DeepProduct.YEARLY))
    access.adopt(ServerEntitlement.lapsed)
    assertTrue(access.hasPremium.value)
  }

  @Test
  @DisplayName("Server yes, store no: unlocked")
  fun serverYesStoreNo() = runTest {
    val access = access()
    access.adopt(ServerEntitlement.member)
    assertTrue(access.hasPremium.value)
  }

  @Test
  @DisplayName("Both no: locked")
  fun bothNo() = runTest {
    val access = access()
    access.adopt(ServerEntitlement.lapsed)
    assertFalse(access.hasPremium.value)
  }

  @Test
  @DisplayName("Both unknown: locked")
  fun bothUnknown() = runTest {
    val access = access(store = SubscriptionState.Unknown)
    assertNull(access.server.value)
    assertFalse(access.hasPremium.value)
  }

  @Test
  @DisplayName("Store still checking, server last said yes: unlocked from launch")
  fun rememberedServerCarriesUnknownStore() = runTest {
    val blob = InMemoryBlobStore()
    val first = access(blob = blob)
    first.identify("u1")
    first.adopt(ServerEntitlement.member)

    val relaunched = access(store = SubscriptionState.Unknown, blob = blob)
    relaunched.restore()
    assertEquals(true, relaunched.server.value)
    assertTrue(relaunched.hasPremium.value)
  }

  @Test
  @DisplayName("An older server that sends no entitlement changes nothing")
  fun olderServerSilent() = runTest {
    val access = access(store = SubscriptionState.Subscribed(DeepProduct.MONTHLY))
    access.adopt(null)
    assertNull(access.server.value)
    assertTrue(access.hasPremium.value)
    assertEquals(0, access.flipCount)
  }

  // MARK: - Offline

  @Test
  @DisplayName("Server unreachable: the store's yes stands")
  fun offlineFallsBackToStore() = runTest {
    val fetcher = ScriptedFetcher(answers = listOf(Result.failure(ScriptedFetcher.Unreachable())))
    val access = access(store = SubscriptionState.Subscribed(DeepProduct.YEARLY), fetcher = fetcher)
    access.refresh()
    assertEquals(1, fetcher.currentCalls)
    assertTrue(access.hasPremium.value)
  }

  @Test
  @DisplayName("Server unreachable: a remembered yes never regresses to locked")
  fun offlineKeepsRememberedYes() = runTest {
    val blob = InMemoryBlobStore()
    access(blob = blob).adopt(ServerEntitlement.member)

    val fetcher = ScriptedFetcher(answers = listOf(Result.failure(ScriptedFetcher.Unreachable())))
    val access = access(fetcher = fetcher, blob = blob)
    access.refresh()
    assertTrue(access.hasPremium.value)
  }

  @Test
  @DisplayName("refreshIfUnanswered asks only when the session hasn't answered")
  fun refreshIfUnanswered() = runTest {
    val fetcher = ScriptedFetcher(answers = listOf(Result.success(ServerEntitlement.member)))
    val access = access(fetcher = fetcher)
    access.adopt(ServerEntitlement.lapsed)
    access.refreshIfUnanswered()
    assertEquals(0, fetcher.currentCalls)

    val fresh = access(fetcher = fetcher)
    fresh.refreshIfUnanswered()
    assertEquals(1, fetcher.currentCalls)
    assertTrue(fresh.hasPremium.value)
  }

  // MARK: - Identity

  @Test
  @DisplayName("Signing out forgets the server's answer, on disk too")
  fun signOutForgets() = runTest {
    val blob = InMemoryBlobStore()
    val access = access(blob = blob)
    access.identify("u1")
    access.adopt(ServerEntitlement.member)
    access.identify(null)
    assertNull(access.server.value)
    assertFalse(access.hasPremium.value)

    val relaunched = access(blob = blob)
    relaunched.restore()
    assertNull(relaunched.server.value)
  }

  @Test
  @DisplayName("A different member never inherits the last one's answer")
  fun otherMemberStartsFresh() = runTest {
    val blob = InMemoryBlobStore()
    val first = access(blob = blob)
    first.identify("u1")
    first.adopt(ServerEntitlement.member)

    val next = access(blob = blob)
    next.identify("u2")
    assertNull(next.server.value)
    assertFalse(next.hasPremium.value)
  }

  @Test
  @DisplayName("The same member relaunching keeps their answer")
  fun sameMemberKeeps() = runTest {
    val blob = InMemoryBlobStore()
    val first = access(blob = blob)
    first.identify("u1")
    first.adopt(ServerEntitlement.member)

    val relaunched = access(blob = blob)
    relaunched.identify("u1")
    assertTrue(relaunched.hasPremium.value)
  }

  @Test
  @DisplayName("An answer that lands after sign-out is dropped, never inherited")
  fun lateAnswerAfterSignOutDropped() = runTest {
    val gate = CompletableDeferred<Unit>()
    val fetcher = ScriptedFetcher(answers = listOf(Result.success(ServerEntitlement.member))).also { it.gate = gate }
    val access = access(fetcher = fetcher)
    access.identify("u1")
    val late = async { access.refresh() }
    runCurrent()
    access.identify(null)
    gate.complete(Unit)
    late.await()
    access.identify("u2")
    assertNull(access.server.value)
    assertFalse(access.hasPremium.value)
  }

  @Test
  @DisplayName("An ownerless remembered answer is never stamped onto the next member")
  fun ownerlessAnswerForgotten() = runTest {
    val blob = InMemoryBlobStore()
    access(blob = blob).adopt(ServerEntitlement.member)
    val next = access(blob = blob)
    next.identify("u2")
    assertNull(next.server.value)
  }

  // MARK: - Grace window

  @Test
  @DisplayName("A purchase unlocks at once, then the window expires on its own")
  fun graceWindowOpensAndExpires() = runTest {
    val access = access()
    access.didPurchase()
    assertTrue(access.hasPremium.value)

    advanceTimeBy(ReconciledPremiumAccess.GRACE_WINDOW_MILLIS - 1)
    runCurrent()
    assertTrue(access.hasPremium.value)

    advanceTimeBy(2)
    runCurrent()
    assertFalse(access.hasPremium.value)
  }

  @Test
  @DisplayName("After a purchase the server is nudged once, then polled until it agrees")
  fun confirmationLadderStopsWhenServerAgrees() = runTest {
    val fetcher = ScriptedFetcher(
      answers = listOf(
        Result.success(ServerEntitlement.lapsed),
        Result.success(ServerEntitlement.member),
        Result.success(ServerEntitlement.member),
      ),
    )
    val access = access(fetcher = fetcher)
    access.confirmPurchase()
    assertEquals(1, fetcher.refreshCalls)
    assertEquals(true, access.server.value)
    // It stopped asking the moment the server agreed: two rungs.
    assertEquals(2, fetcher.currentCalls)
  }

  @Test
  @DisplayName("The ladder ends after its last rung when the server never agrees")
  fun confirmationLadderEnds() = runTest {
    val fetcher = ScriptedFetcher(answers = listOf(Result.success(ServerEntitlement.lapsed)))
    val access = access(fetcher = fetcher)
    access.confirmPurchase()
    assertEquals(1, fetcher.refreshCalls)
    assertEquals(ReconciledPremiumAccess.CONFIRMATION_DELAYS_MILLIS.size, fetcher.currentCalls)
    assertEquals(false, access.server.value)
  }

  @Test
  @DisplayName("A second purchase replaces the first ladder rather than running two")
  fun newPurchaseCancelsOldLadder() = runTest {
    val fetcher = ScriptedFetcher(answers = listOf(Result.success(ServerEntitlement.lapsed)))
    val access = access(fetcher = fetcher)
    access.didPurchase()
    runCurrent()
    advanceTimeBy(1_500)
    access.didPurchase()
    advanceTimeBy(10 * 60_000)
    runCurrent()
    // One full ladder (7 rungs) plus the first's one rung before it was replaced.
    assertEquals(ReconciledPremiumAccess.CONFIRMATION_DELAYS_MILLIS.size + 1, fetcher.currentCalls)
    assertEquals(2, fetcher.refreshCalls)
  }

  @Test
  @DisplayName("Signing out stops the ladder")
  fun signOutStopsLadder() = runTest {
    val fetcher = ScriptedFetcher(answers = listOf(Result.success(ServerEntitlement.lapsed)))
    val access = access(fetcher = fetcher)
    access.identify("u1")
    access.didPurchase()
    runCurrent()
    access.identify(null)
    advanceTimeBy(10 * 60_000)
    runCurrent()
    assertEquals(0, fetcher.currentCalls)
    assertFalse(access.hasPremium.value)
  }

  // MARK: - Flip counter and content epoch

  @Test
  @DisplayName("The flip counter moves exactly once per flip")
  fun flipCountOncePerFlip() = runTest {
    val access = access()
    assertEquals(0, access.flipCount)

    access.adopt(ServerEntitlement.member)
    assertEquals(1, access.flipCount)
    access.adopt(ServerEntitlement.member)
    access.reconcile()
    assertEquals(1, access.flipCount)

    access.adopt(ServerEntitlement.lapsed)
    assertEquals(2, access.flipCount)
    access.adopt(ServerEntitlement.lapsed)
    assertEquals(2, access.flipCount)
  }

  @Test
  @DisplayName("The server catching up after a purchase re-fetches content without a flip")
  fun serverCatchUpMovesContentEpoch() = runTest {
    val access = access()
    access.adopt(ServerEntitlement.lapsed)
    val start = access.contentEpoch.value
    access.didPurchase()
    assertEquals(1, access.flipCount)
    assertEquals(start + 1, access.contentEpoch.value)

    // Already unlocked on the store's word; the server now releases the audio.
    access.adopt(ServerEntitlement.member)
    assertEquals(1, access.flipCount)
    assertEquals(start + 2, access.contentEpoch.value)

    // Saying the same thing again moves nothing.
    access.adopt(ServerEntitlement.member)
    assertEquals(start + 2, access.contentEpoch.value)
  }

  @Test
  @DisplayName("The server's first answer, arriving under a grace window, still re-fetches")
  fun firstAnswerUnderGraceMovesEpoch() = runTest {
    val access = access()
    access.didPurchase()
    val before = access.contentEpoch.value
    access.adopt(ServerEntitlement.member)
    assertEquals(before + 1, access.contentEpoch.value)
  }

  @Test
  @DisplayName("A grace window over an already-premium member is no flip")
  fun graceOverMemberNoFlip() = runTest {
    val access = access(store = SubscriptionState.Subscribed(DeepProduct.YEARLY))
    access.didPurchase()
    assertEquals(0, access.flipCount)
  }

  @Test
  @DisplayName("The store settling reaches the answer without anyone calling in")
  fun storeObservationFlips() = runTest {
    val store = MutableStateFlow<SubscriptionState>(SubscriptionState.None)
    val access = access(storeFlow = store)
    store.value = SubscriptionState.Subscribed(DeepProduct.YEARLY)
    runCurrent()
    assertTrue(access.hasPremium.value)
    assertEquals(1, access.flipCount)
  }

  // MARK: - Persistence

  @Test
  @DisplayName("The remembered answer is written as {owner, active}")
  fun blobShape() = runTest {
    val blob = InMemoryBlobStore()
    val access = access(blob = blob)
    access.identify("u1")
    access.adopt(ServerEntitlement.member)
    assertEquals("""{"owner":"u1","active":true}""", blob.value)
  }
}
