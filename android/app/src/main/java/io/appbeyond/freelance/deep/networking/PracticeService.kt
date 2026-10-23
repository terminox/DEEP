package io.appbeyond.freelance.deep.networking

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST

/**
 * The practice journal's sync (`routes/practice.ts`). Paths are relative —
 * see [PauseHomeService] for why.
 *
 * Both routes are idempotent by the client-generated session id: a re-sent
 * session is skipped on insert and its award comes back `cappedBy: "duplicate"`
 * rather than granted twice, which is what lets the journal retry a whole
 * batch after a dropped response without bookkeeping of its own.
 */
interface PracticeService {

  /** Auth required. At most 200 sessions; awards and the post-award wallet ride the reply. */
  @POST("me/practice/sessions")
  suspend fun push(@Body body: PracticeSyncRequest): PracticeSyncResponseDto

  /** Auth required. The member's whole log, from every install. */
  @GET("me/practice/sessions")
  suspend fun sessions(): PracticeSessionsResponseDto
}
