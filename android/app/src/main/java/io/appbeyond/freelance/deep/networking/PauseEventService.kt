package io.appbeyond.freelance.deep.networking

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * The live Global Pause event (`routes/pauseLive.ts`). Paths are relative —
 * see [PauseHomeService] for why.
 *
 * Auth, per route, as the server declares it:
 * - `optionalAuth`: the schedule, presence and the live poll. Signed-in beats
 *   also leave the durable attendance record the award judges, so a stale
 *   token here must not quietly turn anonymous: since PR #58 the server
 *   answers it with a 401, and `DeepHttp`'s authenticator refreshes and
 *   retries once — any 401 on a request that carried a bearer, whatever the
 *   route. A refused refresh ends the session as everywhere else.
 * - `requireAuth`: posting a message, the reflection, the award claim.
 * - None: reading the message feed.
 */
interface PauseEventService {

  @GET("pause/schedule")
  suspend fun schedule(): PauseScheduleDto

  @POST("pause/presence/heartbeat")
  suspend fun heartbeat(@Body body: PauseHeartbeatRequest): PauseHeartbeatResponse

  @DELETE("pause/presence/{presenceId}")
  suspend fun leave(@Path("presenceId") presenceId: String): PauseOkResponse

  @GET("pause/live")
  suspend fun live(): PauseLiveDto

  /** [cursor] is server-issued base64url — passed back verbatim. */
  @GET("pause/messages")
  suspend fun messages(
    @Query("limit") limit: Int,
    @Query("cursor", encoded = true) cursor: String?,
  ): PeaceMessagesResponse

  /** 403 `message_limit` past three a day; 401 signed out. */
  @POST("pause/messages")
  suspend fun postMessage(@Body body: PeaceMessagePostRequest): PeaceMessagePostResponse

  @POST("pause/reflection")
  suspend fun reflection(@Body body: PauseReflectionRequest): PauseOkResponse

  /**
   * No body at all — and so no `Content-Type`, which Fastify would otherwise
   * read as an empty JSON body and refuse.
   */
  @POST("me/pause/award")
  suspend fun claimAward(): PauseAwardResponse
}
