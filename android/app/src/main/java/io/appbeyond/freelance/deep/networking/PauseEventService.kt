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
 * - `requireAuth`: posting a message, the reflection, the award claim, and
 *   Report and Block (the report, the block, the blocked list, unblocking).
 * - `optionalAuth` too: reading the message feed. A signed-in reader's feed
 *   leaves out what they reported and whose author they blocked, which the
 *   bearer `DeepHttp` attaches whenever there is a session is enough for.
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

  /**
   * 403 `message_limit` past three a day; 401 signed out; 422
   * `message_rejected` when the text trips the server's content filter.
   */
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

  /** Idempotent. 400 `own_message` for the caller's own; 404 unknown id. */
  @POST("pause/messages/{id}/report")
  suspend fun report(@Path("id") messageId: String, @Body body: PeaceMessageReportRequest): ModerationOkResponse

  /** No body, as [claimAward]. Idempotent. 400 `own_message`; 404 unknown id. */
  @POST("pause/messages/{id}/block-author")
  suspend fun blockAuthor(@Path("id") messageId: String): BlockAuthorResponse

  @GET("me/blocks")
  suspend fun blockedMembers(): BlockedMembersResponse

  /** Idempotent: an unknown id is a 200 no-op. */
  @DELETE("me/blocks/{id}")
  suspend fun unblock(@Path("id") blockId: String): ModerationOkResponse
}
