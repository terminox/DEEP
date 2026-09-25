package io.appbeyond.freelance.deep.networking

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.PUT

/** The onboarding config, and a signed-in member's saved progress. */
interface OnboardingService {

  /** Anonymous; the coordinator in `:core:model` owns the retry schedule. */
  @GET("onboarding/config")
  suspend fun config(): OnboardingConfigDto

  @GET("me/onboarding")
  suspend fun profile(): OnboardingProfileDto

  /** Always sends the FULL state — the server replaces answers + tree wholesale. */
  @PUT("me/onboarding")
  suspend fun putProfile(@Body body: OnboardingPutRequestDto): OnboardingProfileDto
}
