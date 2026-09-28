package io.appbeyond.freelance.deep.networking

import kotlinx.serialization.Serializable
import retrofit2.http.Body
import retrofit2.http.POST

/**
 * The listen report — `POST /me/sound/listens` (`routes/sound.ts`).
 *
 * A Retrofit service on the one shared client, not a call on the media client:
 * the server keys the award to the member's *local* day, so the report must
 * carry `X-Device-Timezone` and the bearer token like any other Deep request.
 *
 * The reply is an award outcome plus a rewards snapshot. It is discarded for
 * now — the heart ledger and garden it would reconcile, which iOS feeds it to
 * through `ingestAwards` (`AppDependencies.swift`), are not ported yet.
 */
interface SoundListensService {

  @POST("me/sound/listens")
  suspend fun report(@Body body: ListenRequest)
}

@Serializable
data class ListenRequest(val trackId: String)
