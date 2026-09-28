package io.appbeyond.freelance.deep.feature.deepsound.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ListenRulesTest {

  // MARK: - shouldReportListen

  @Test
  @DisplayName("a natural, playable listen while signed in is reported")
  fun naturalPlayableSignedInIsReported() {
    assertTrue(ListenRules.shouldReportListen(Advance.Natural, playable = true, signedIn = true))
  }

  @Test
  @DisplayName("a skip never counts as a listen")
  fun skipIsNeverReported() {
    assertFalse(ListenRules.shouldReportListen(Advance.Skip, playable = true, signedIn = true))
  }

  @Test
  @DisplayName("a seek never counts as a listen")
  fun seekIsNeverReported() {
    assertFalse(ListenRules.shouldReportListen(Advance.Seek, playable = true, signedIn = true))
  }

  @Test
  @DisplayName("a track with no audio to play is never reported")
  fun unplayableTrackIsNeverReported() {
    assertFalse(ListenRules.shouldReportListen(Advance.Natural, playable = false, signedIn = true))
  }

  @Test
  @DisplayName("a signed-out listener is never reported")
  fun signedOutIsNeverReported() {
    assertFalse(ListenRules.shouldReportListen(Advance.Natural, playable = true, signedIn = false))
  }

  // MARK: - shouldClearPlayer

  @Test
  @DisplayName("signing in for the first time does not clear the player")
  fun firstSignInDoesNotClear() {
    assertFalse(ListenRules.shouldClearPlayer(beforeAccountId = null, afterAccountId = "A"))
  }

  @Test
  @DisplayName("signing out clears the player")
  fun signingOutClears() {
    assertTrue(ListenRules.shouldClearPlayer(beforeAccountId = "A", afterAccountId = null))
  }

  @Test
  @DisplayName("switching to a different account clears the player")
  fun switchingAccountsClears() {
    assertTrue(ListenRules.shouldClearPlayer(beforeAccountId = "A", afterAccountId = "B"))
  }

  @Test
  @DisplayName("the same account restoring itself does not clear the player")
  fun sameAccountDoesNotClear() {
    assertFalse(ListenRules.shouldClearPlayer(beforeAccountId = "A", afterAccountId = "A"))
  }
}
