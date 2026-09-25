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

  @GET("me")
  suspend fun me(): MeResponseDto

  @DELETE("me")
  suspend fun deleteMe(): OkResponseDto
}
