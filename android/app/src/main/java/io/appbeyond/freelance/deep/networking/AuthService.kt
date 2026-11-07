package io.appbeyond.freelance.deep.networking

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.POST

/**
 * The account lifecycle: signup, login, logout, `/me`. Paths are relative —
 * see [PauseHomeService] for why.
 */
interface AuthService {

  @POST("auth/signup")
  suspend fun signUp(@Body body: SignUpRequestDto): AuthResponseDto

  @POST("auth/login")
  suspend fun logIn(@Body body: LogInRequestDto): AuthResponseDto

  /** Bearer-authorized when a session exists; no body either way. */
  @POST("auth/logout")
  suspend fun logOut(): OkResponseDto

  /** The member and, beside them, their DEEP Premium answer. */
  @GET("me")
  suspend fun me(): MeResponseDto

  /**
   * Asks the server to re-check DEEP Premium with RevenueCat now rather than
   * wait for the webhook. Rate-limited per member (429), and 503
   * `not_configured` on a server without a RevenueCat secret — both of which
   * the post-purchase ladder simply outlasts.
   */
  @POST("me/entitlement/refresh")
  suspend fun refreshEntitlement(): EntitlementResponseDto

  @DELETE("me")
  suspend fun deleteMe(): OkResponseDto
}
