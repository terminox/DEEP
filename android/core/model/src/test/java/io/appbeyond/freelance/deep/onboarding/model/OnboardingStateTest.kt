package io.appbeyond.freelance.deep.onboarding.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Ported from Deep/Deep/Features/Onboarding/Models/OnboardingState.swift. */
class OnboardingStateTest {

  @Test
  @DisplayName("recordingAnswer adds a question without disturbing the others")
  fun recordingAnswerAdds() {
    val state = OnboardingState.Fresh
      .recordingAnswer("q1", "a")
      .recordingAnswer("q2", "b")

    assertEquals(mapOf("q1" to "a", "q2" to "b"), state.quizAnswers)
  }

  @Test
  @DisplayName("recordingAnswer overwrites an existing answer for the same question")
  fun recordingAnswerOverwrites() {
    val state = OnboardingState.Fresh
      .recordingAnswer("q1", "a")
      .recordingAnswer("q1", "b")

    assertEquals(mapOf("q1" to "b"), state.quizAnswers)
  }

  @Test
  @DisplayName("recordingMindTree sets the tree without touching answers or completion")
  fun recordingMindTree() {
    val state = OnboardingState.Fresh
      .recordingAnswer("q1", "a")
      .recordingMindTree("oak")

    assertEquals("oak", state.mindTree)
    assertEquals(mapOf("q1" to "a"), state.quizAnswers)
    assertFalse(state.hasCompletedOnboarding)
  }

  @Test
  @DisplayName("completed sets the flag without touching answers or the tree")
  fun completed() {
    val state = OnboardingState.Fresh
      .recordingAnswer("q1", "a")
      .recordingMindTree("oak")
      .completed()

    assertTrue(state.hasCompletedOnboarding)
    assertEquals(mapOf("q1" to "a"), state.quizAnswers)
    assertEquals("oak", state.mindTree)
  }

  @Test
  @DisplayName("hydrated replaces everything wholesale, ignoring any prior state")
  fun hydrated() {
    val state = OnboardingState.hydrated(
      quizAnswers = mapOf("q1" to "a"),
      mindTree = "willow",
      completed = true,
    )

    assertEquals(OnboardingState(hasCompletedOnboarding = true, quizAnswers = mapOf("q1" to "a"), mindTree = "willow"), state)
  }

  @Test
  @DisplayName("Fresh is the clean first-run state")
  fun fresh() {
    assertEquals(OnboardingState(), OnboardingState.Fresh)
  }
}
