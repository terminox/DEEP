package io.appbeyond.freelance.deep.feature.premium.model

import io.appbeyond.freelance.deep.feature.premium.store.SubscriptionStatusCache
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * The plan chip's words, where Settings sends a member to manage DEEP
 * Premium (SubscriptionManagementTests.swift, with Google Play in the App
 * Store's place), and the store cache's iOS spelling.
 */
class MembershipTest {

  // MARK: - Plan chip

  @Test
  @DisplayName("The store's product names the plan, in either id shape")
  fun planFromProduct() {
    assertEquals(PlanLabel.PremiumYearly, PlanLabel.of(SubscriptionState.Subscribed("deep.pro.yearly"), hasPremium = true))
    assertEquals(PlanLabel.PremiumMonthly, PlanLabel.of(SubscriptionState.Subscribed("deep.pro.monthly:monthly"), hasPremium = true))
    assertEquals(PlanLabel.Premium, PlanLabel.of(SubscriptionState.Subscribed("deep.lifetime"), hasPremium = true))
  }

  @Test
  @DisplayName("A membership the store can't see still reads as DEEP Premium")
  fun serverOnlyMembership() {
    assertEquals(PlanLabel.Premium, PlanLabel.of(SubscriptionState.None, hasPremium = true))
    assertEquals(PlanLabel.Premium, PlanLabel.of(SubscriptionState.Unknown, hasPremium = true))
  }

  @Test
  @DisplayName("No membership reads Free once the store has answered, Checking until then")
  fun freeOrChecking() {
    assertEquals(PlanLabel.Free, PlanLabel.of(SubscriptionState.None, hasPremium = false))
    assertEquals(PlanLabel.Checking, PlanLabel.of(SubscriptionState.Unknown, hasPremium = false))
  }

  // MARK: - Manage subscription

  @Test
  @DisplayName("A Play purchase is managed on Play's page for that subscription")
  fun playStore() {
    val management = SubscriptionManagement.of(
      store = "PLAY_STORE",
      productId = "deep.pro.yearly:yearly",
      managementUrl = "https://billing.example.test/manage",
    )
    assertEquals(SubscriptionManagement.GooglePlay("deep.pro.yearly"), management)
    assertEquals(
      "https://play.google.com/store/account/subscriptions?sku=deep.pro.yearly&package=io.appbeyond.freelance.deep",
      management.url("io.appbeyond.freelance.deep"),
    )
  }

  @Test
  @DisplayName("A purchase made elsewhere is managed at the page RevenueCat names")
  fun elsewhere() {
    val management = SubscriptionManagement.of(
      store = "APP_STORE",
      productId = "deep.pro.yearly",
      managementUrl = "https://apps.apple.com/account/subscriptions",
    )
    assertEquals("https://apps.apple.com/account/subscriptions", management.url("io.appbeyond.freelance.deep"))
  }

  @Test
  @DisplayName("Elsewhere with no page named falls back to Play's subscriptions")
  fun elsewhereWithoutPage() {
    val management = SubscriptionManagement.of(store = "PROMOTIONAL", productId = "deep.pro.yearly", managementUrl = null)
    assertEquals(SubscriptionManagement.PLAY_SUBSCRIPTIONS, management.url("io.appbeyond.freelance.deep"))
  }

  @Test
  @DisplayName("A membership the store can't see is managed where the server says it was bought")
  fun serverOnlyMembershipManagement() {
    val play = SubscriptionManagement.forMember(
      store = SubscriptionState.None,
      storeManagement = SubscriptionManagement.GooglePlay(null),
      server = ServerEntitlement(isActive = true, productId = "deep.pro.monthly", store = "PLAY_STORE"),
    )
    assertEquals(SubscriptionManagement.GooglePlay("deep.pro.monthly"), play)

    val storeSees = SubscriptionManagement.forMember(
      store = SubscriptionState.Subscribed("deep.pro.yearly"),
      storeManagement = SubscriptionManagement.GooglePlay("deep.pro.yearly"),
      server = ServerEntitlement(isActive = true, store = "PROMOTIONAL"),
    )
    assertEquals(SubscriptionManagement.GooglePlay("deep.pro.yearly"), storeSees)

    val granted = SubscriptionManagement.forMember(
      store = SubscriptionState.None,
      storeManagement = SubscriptionManagement.GooglePlay(null),
      server = ServerEntitlement(isActive = true, store = "PROMOTIONAL"),
    )
    assertEquals(SubscriptionManagement.PLAY_SUBSCRIPTIONS, granted.url("io.appbeyond.freelance.deep"))
  }

  // MARK: - Store cache

  @Test
  @DisplayName("The store cache speaks iOS's spelling")
  fun cacheSpelling() = runTest {
    val blob = InMemoryBlobStore()
    val cache = SubscriptionStatusCache(blob)
    assertNull(cache.load())

    cache.save(SubscriptionState.Subscribed(DeepProduct.YEARLY))
    assertEquals("subscribed:deep.pro.yearly", blob.value)
    assertEquals(SubscriptionState.Subscribed(DeepProduct.YEARLY), cache.load())

    cache.save(SubscriptionState.None)
    assertEquals("none", blob.value)
    assertEquals(SubscriptionState.None, cache.load())

    // The transient state is never remembered.
    cache.save(SubscriptionState.Unknown)
    assertEquals("none", blob.value)
  }

  @Test
  @DisplayName("A value the cache never wrote reads as nothing remembered")
  fun cacheIgnoresStrangers() = runTest {
    assertNull(SubscriptionStatusCache(InMemoryBlobStore("pro")).load())
  }
}
