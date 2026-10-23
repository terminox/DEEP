package io.appbeyond.freelance.deep.feature.onboarding.store

import io.appbeyond.freelance.deep.onboarding.model.OnboardingState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * In-memory [OnboardingProgressStore] for previews — no persistence, no side
 * effects. The Android twin of `MockOnboardingStore.swift`.
 *
 * Every mutation is synchronous and never suspends, so — like
 * [DataStoreOnboardingProgressStore] — `state.value` is right the instant the
 * call is made and a caller's cancelled scope can't drop it.
 */
class MockOnboardingProgressStore(state: OnboardingState = OnboardingState.Fresh) : OnboardingProgressStore {

  private val _state = MutableStateFlow(state)
  override val state: StateFlow<OnboardingState> = _state.asStateFlow()

  override suspend fun recordAnswer(questionId: String, optionId: String) {
    _state.value = _state.value.recordingAnswer(questionId, optionId)
  }

  override suspend fun recordMindTree(id: String) {
    _state.value = _state.value.recordingMindTree(id)
  }

  override suspend fun completeOnboarding() {
    _state.value = _state.value.completed()
  }

  override suspend fun hydrate(quizAnswers: Map<String, String>, mindTree: String?, completed: Boolean) {
    _state.value = OnboardingState.hydrated(quizAnswers, mindTree, completed)
  }

  override suspend fun reset() {
    _state.value = OnboardingState.Fresh
  }

  companion object {
    /** A clean first run. */
    val fresh: MockOnboardingProgressStore get() = MockOnboardingProgressStore()

    /** A couple of answers already recorded, partway through the quiz. */
    val midQuiz: MockOnboardingProgressStore
      get() = MockOnboardingProgressStore(
        OnboardingState(quizAnswers = mapOf("arrival" to "slow-down", "longing" to "calm"))
      )
  }
}
