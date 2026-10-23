package io.appbeyond.freelance.deep.onboarding.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertSame

/**
 * Ported from `OnboardingCoordinatorView.advance(to:)` / `goBack()`, plus the
 * week-2 loop fix (signed-in CreateAccount routes to CraftingSpace instead).
 */
class OnboardingNavigatorTest {

  // MARK: - advance: pending quiz + replay

  @Test
  @DisplayName("a Quiz route requested before the config loads is held as pending, stack unchanged")
  fun pendingQuizHeldUntilConfigLoads() {
    val nav = OnboardingNavigator.advance(
      OnboardingNav(),
      to = OnboardingRoute.Quiz(0),
      configLoaded = false,
      signedIn = false,
    )

    assertEquals(emptyList(), nav.stack)
    assertEquals(OnboardingRoute.Quiz(0), nav.pending)
  }

  @Test
  @DisplayName("configLoaded replays the pending route with the same rules, then clears it")
  fun configLoadedReplaysPending() {
    val pending = OnboardingNavigator.advance(
      OnboardingNav(),
      to = OnboardingRoute.Quiz(0),
      configLoaded = false,
      signedIn = false,
    )

    val replayed = OnboardingNavigator.configLoaded(pending, signedIn = false)

    assertEquals(listOf(OnboardingRoute.Quiz(0)), replayed.stack)
    assertNull(replayed.pending)
    assertEquals(NavDirection.Forward, replayed.direction)
  }

  @Test
  @DisplayName("configLoaded is a no-op when nothing is pending")
  fun configLoadedNoPending() {
    val nav = OnboardingNav(stack = listOf(OnboardingRoute.CreateAccount))

    val result = OnboardingNavigator.configLoaded(nav, signedIn = false)

    assertSame(nav, result)
  }

  @Test
  @DisplayName("configLoaded replay applies the signed-in loop fix too")
  fun configLoadedReplayAppliesLoopFix() {
    // Can't literally reach this via advance() (Quiz is never held pending
    // behind CreateAccount), but configLoaded must still run the pending
    // route through the *same* advance() rules — this pins that it does by
    // constructing the pending state directly.
    val nav = OnboardingNav(stack = listOf(OnboardingRoute.Quiz(0)), pending = OnboardingRoute.CreateAccount)

    val result = OnboardingNavigator.configLoaded(nav, signedIn = true)

    assertEquals(listOf(OnboardingRoute.Quiz(0), OnboardingRoute.CraftingSpace), result.stack)
    assertNull(result.pending)
  }

  // MARK: - advance: duplicate ignored

  @Test
  @DisplayName("advancing to the route already on top is a no-op")
  fun duplicateIgnored() {
    val nav = OnboardingNav(stack = listOf(OnboardingRoute.Quiz(0)), direction = NavDirection.Backward)

    val result = OnboardingNavigator.advance(nav, to = OnboardingRoute.Quiz(0), configLoaded = true, signedIn = false)

    assertSame(nav, result)
  }

  // MARK: - advance: signed-in CreateAccount loop fix

  @Test
  @DisplayName("advancing to CreateAccount while signed in pushes CraftingSpace instead")
  fun signedInCreateAccountRedirectsToCraftingSpace() {
    val nav = OnboardingNav(stack = listOf(OnboardingRoute.MindTree))

    val result = OnboardingNavigator.advance(nav, to = OnboardingRoute.CreateAccount, configLoaded = true, signedIn = true)

    assertEquals(listOf(OnboardingRoute.MindTree, OnboardingRoute.CraftingSpace), result.stack)
    assertEquals(NavDirection.Forward, result.direction)
  }

  @Test
  @DisplayName("advancing to CreateAccount while signed out pushes CreateAccount as normal")
  fun signedOutCreateAccountPushesNormally() {
    val nav = OnboardingNav(stack = listOf(OnboardingRoute.MindTree))

    val result = OnboardingNavigator.advance(nav, to = OnboardingRoute.CreateAccount, configLoaded = true, signedIn = false)

    assertEquals(listOf(OnboardingRoute.MindTree, OnboardingRoute.CreateAccount), result.stack)
  }

  // MARK: - advance: LogIn -> Quiz replaces the stack

  @Test
  @DisplayName("advancing to Quiz from LogIn replaces the whole stack, so back returns to welcome")
  fun logInToQuizReplacesStack() {
    val nav = OnboardingNav(stack = listOf(OnboardingRoute.LogIn))

    val result = OnboardingNavigator.advance(nav, to = OnboardingRoute.Quiz(0), configLoaded = true, signedIn = true)

    assertEquals(listOf(OnboardingRoute.Quiz(0)), result.stack)
    assertEquals(NavDirection.Forward, result.direction)
  }

  // MARK: - advance: default push

  @Test
  @DisplayName("otherwise, advance pushes and sets direction Forward")
  fun otherwisePushes() {
    val nav = OnboardingNav(stack = listOf(OnboardingRoute.Quiz(0)), direction = NavDirection.Backward)

    val result = OnboardingNavigator.advance(nav, to = OnboardingRoute.Quiz(1), configLoaded = true, signedIn = false)

    assertEquals(listOf(OnboardingRoute.Quiz(0), OnboardingRoute.Quiz(1)), result.stack)
    assertEquals(NavDirection.Forward, result.direction)
  }

  // MARK: - back

  @Test
  @DisplayName("back is a no-op on the welcome screen (empty stack)")
  fun backNoOpOnWelcome() {
    val nav = OnboardingNav()

    val result = OnboardingNavigator.back(nav)

    assertSame(nav, result)
  }

  @Test
  @DisplayName("back is a no-op on CraftingSpace")
  fun backNoOpOnCraftingSpace() {
    val nav = OnboardingNav(stack = listOf(OnboardingRoute.MindTree, OnboardingRoute.CraftingSpace))

    val result = OnboardingNavigator.back(nav)

    assertSame(nav, result)
  }

  @Test
  @DisplayName("back otherwise pops one step and sets direction Backward")
  fun backPops() {
    val nav = OnboardingNav(stack = listOf(OnboardingRoute.Quiz(0), OnboardingRoute.Quiz(1)))

    val result = OnboardingNavigator.back(nav)

    assertEquals(listOf(OnboardingRoute.Quiz(0)), result.stack)
    assertEquals(NavDirection.Backward, result.direction)
  }

  // MARK: - showsChrome

  @Test
  @DisplayName("showsChrome is false on the welcome screen")
  fun showsChromeFalseOnWelcome() {
    assertEquals(false, OnboardingNavigator.showsChrome(OnboardingNav()))
  }

  @Test
  @DisplayName("showsChrome is false on CraftingSpace")
  fun showsChromeFalseOnCraftingSpace() {
    val nav = OnboardingNav(stack = listOf(OnboardingRoute.MindTree, OnboardingRoute.CraftingSpace))
    assertEquals(false, OnboardingNavigator.showsChrome(nav))
  }

  @Test
  @DisplayName("showsChrome is true on every other routed screen")
  fun showsChromeTrueOtherwise() {
    val nav = OnboardingNav(stack = listOf(OnboardingRoute.Quiz(0)))
    assertEquals(true, OnboardingNavigator.showsChrome(nav))
  }

  // MARK: - onboardingProgress

  @Test
  @DisplayName("progress on a Quiz step is (index + 1) of (questionCount + 1)")
  fun progressOnQuiz() {
    val progress = onboardingProgress(OnboardingRoute.Quiz(2), questionCount = 5)

    assertEquals(OnboardingProgress(step = 3, total = 6), progress)
  }

  @Test
  @DisplayName("progress on MindTree is the final step")
  fun progressOnMindTree() {
    val progress = onboardingProgress(OnboardingRoute.MindTree, questionCount = 5)

    assertEquals(OnboardingProgress(step = 6, total = 6), progress)
  }

  @Test
  @DisplayName("progress is null on every other route")
  fun progressNullElsewhere() {
    assertNull(onboardingProgress(OnboardingRoute.CreateAccount, questionCount = 5))
    assertNull(onboardingProgress(OnboardingRoute.SignUp, questionCount = 5))
    assertNull(onboardingProgress(OnboardingRoute.LogIn, questionCount = 5))
    assertNull(onboardingProgress(OnboardingRoute.CraftingSpace, questionCount = 5))
  }

  @Test
  @DisplayName("progress is null on the welcome screen (null route)")
  fun progressNullOnWelcome() {
    assertNull(onboardingProgress(null, questionCount = 5))
  }

  @Test
  @DisplayName("progress with zero questions still counts the Mind Tree step")
  fun progressZeroQuestions() {
    assertEquals(OnboardingProgress(step = 1, total = 1), onboardingProgress(OnboardingRoute.Quiz(0), questionCount = 0))
    assertEquals(OnboardingProgress(step = 1, total = 1), onboardingProgress(OnboardingRoute.MindTree, questionCount = 0))
  }
}
