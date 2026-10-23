package io.appbeyond.freelance.deep.networking

import kotlinx.serialization.Serializable
import retrofit2.http.Body
import retrofit2.http.POST

/**
 * The listen report — `POST /me/sound/listens` (`routes/sound.ts`).
 *
 * A Retrofit service on the one shared client, not a call on the media client:
 * the server keys the award to the member's *local* day, so the report must
 * carry `X-Device-Timezone` and the bearer token like any other DEEP request.
 *
 * The reply is the award outcome plus the shared `{ wallet, plant }` tail
 * ([AwardResponseDto]). `ApiTrackListenReporter` folds it into one grant and
 * hands it to the shared award ingest, so the heart ledger and the garden
 * reconcile to the server's absolutes — iOS's `reportListen` → `ingestAwards`
 * (`AppDependencies.swift`).
 */
interface SoundListensService {

  @POST("me/sound/listens")
  suspend fun report(@Body body: ListenRequest): AwardResponseDto
}

@Serializable
data class ListenRequest(val trackId: String)
