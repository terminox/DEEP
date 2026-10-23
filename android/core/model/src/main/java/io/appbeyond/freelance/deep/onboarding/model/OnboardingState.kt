package io.appbeyond.freelance.deep.onboarding.model

/**
 * Locally-persisted onboarding progress. Ported from
 * Deep/Deep/Features/Onboarding/Models/OnboardingState.swift, which keeps
 * quiz answers as a flat `questionID -> optionID` map so adding or
 * reordering questions never breaks decoding of an older saved state — the
 * same reasoning holds here.
 */
data class OnboardingState(
  val hasCompletedOnboarding: Boolean = false,
  /** questionId → optionId. */
  val quizAnswers: Map<String, String> = emptyMap(),
  val mindTree: String? = null,
) {
  fun recordingAnswer(questionId: String, optionId: String): OnboardingState =
    copy(quizAnswers = quizAnswers + (questionId to optionId))

  fun recordingMindTree(id: String): OnboardingState = copy(mindTree = id)

  fun completed(): OnboardingState = copy(hasCompletedOnboarding = true)

  companion object {
    val Fresh = OnboardingState()

    /** Replaces everything — the server's profile wins wholesale. */
    fun hydrated(quizAnswers: Map<String, String>, mindTree: String?, completed: Boolean): OnboardingState =
      OnboardingState(hasCompletedOnboarding = completed, quizAnswers = quizAnswers, mindTree = mindTree)
  }
}
