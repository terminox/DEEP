package io.appbeyond.freelance.deep.feature.premium.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Which store answers RevenueCatSubscriptionStore adopts, and which it drops. */
class StoreIdentityTest {

  private val anon = "\$RCAnonymousID:0123456789abcdef0123456789abcdef"

  @Test
  @DisplayName("The expected member's own answer fits")
  fun ownAnswer() {
    assertTrue(StoreIdentity.answerFits("u1", storeUserId = "u1", originalUserId = "u1"))
  }

  @Test
  @DisplayName("A member whose customer began anonymous on this install still fits")
  fun aliasedFromAnonymous() {
    assertTrue(StoreIdentity.answerFits("u1", storeUserId = "u1", originalUserId = anon))
  }

  @Test
  @DisplayName("The last member's answer, landing after the next signed in, is dropped")
  fun previousMembersAnswer() {
    assertFalse(StoreIdentity.answerFits("u2", storeUserId = "u2", originalUserId = "u1"))
    assertFalse(StoreIdentity.answerFits("u2", storeUserId = "u1", originalUserId = "u1"))
  }

  @Test
  @DisplayName("An anonymous answer while a member is signed in is dropped")
  fun anonymousWhileSignedIn() {
    assertFalse(StoreIdentity.answerFits("u1", storeUserId = anon, originalUserId = anon))
  }

  @Test
  @DisplayName("Signed out, only an anonymous answer fits")
  fun signedOut() {
    assertTrue(StoreIdentity.answerFits(null, storeUserId = anon, originalUserId = anon))
    assertFalse(StoreIdentity.answerFits(null, storeUserId = "u1", originalUserId = "u1"))
  }
}
