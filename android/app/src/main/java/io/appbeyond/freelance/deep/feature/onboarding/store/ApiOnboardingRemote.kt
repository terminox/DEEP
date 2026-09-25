package io.appbeyond.freelance.deep.feature.onboarding.store

import io.appbeyond.freelance.deep.networking.OnboardingPutRequestDto
import io.appbeyond.freelance.deep.networking.OnboardingService
import io.appbeyond.freelance.deep.networking.apiCall
import io.appbeyond.freelance.deep.networking.toDomain
import io.appbeyond.freelance.deep.onboarding.model.OnboardingConfig
import io.appbeyond.freelance.deep.onboarding.model.OnboardingState

/** [OnboardingRemote] over deep-api. The Android twin of `APIOnboardingRemote.swift`. */
class ApiOnboardingRemote(private val service: OnboardingService) : OnboardingRemote {

  override suspend fun fetchConfig(): OnboardingConfig =
    apiCall { service.config() }.toDomain()

  override suspend fun fetchProfile(): OnboardingProfile {
    val dto = apiCall { service.profile() }
    return OnboardingProfile(quizAnswers = dto.quizAnswers, mindTree = dto.mindTree, completed = dto.completed)
  }

  override suspend fun submit(state: OnboardingState) {
    apiCall {
      service.putProfile(
        OnboardingPutRequestDto(
          quizAnswers = state.quizAnswers,
          mindTree = state.mindTree,
          completed = state.hasCompletedOnboarding,
        )
      )
    }
  }
}
