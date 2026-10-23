package io.appbeyond.freelance.deep.onboarding.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

/** The full restored × signedIn × completedOnboarding truth table. Ported from `AppRootView.Phase`. */
class RootPhaseTest {

  @Test
  @DisplayName("not restored is always Restoring, regardless of sign-in or completion")
  fun notRestored() {
    assertEquals(RootPhase.Restoring, rootPhase(restored = false, signedIn = false, completedOnboarding = false))
    assertEquals(RootPhase.Restoring, rootPhase(restored = false, signedIn = false, completedOnboarding = true))
    assertEquals(RootPhase.Restoring, rootPhase(restored = false, signedIn = true, completedOnboarding = false))
    assertEquals(RootPhase.Restoring, rootPhase(restored = false, signedIn = true, completedOnboarding = true))
  }

  @Test
  @DisplayName("restored, signed in and completed is Main")
  fun main() {
    assertEquals(RootPhase.Main, rootPhase(restored = true, signedIn = true, completedOnboarding = true))
  }

  @Test
  @DisplayName("restored but missing sign-in or completion is Flow")
  fun flow() {
    assertEquals(RootPhase.Flow, rootPhase(restored = true, signedIn = false, completedOnboarding = false))
    assertEquals(RootPhase.Flow, rootPhase(restored = true, signedIn = false, completedOnboarding = true))
    assertEquals(RootPhase.Flow, rootPhase(restored = true, signedIn = true, completedOnboarding = false))
  }
}
