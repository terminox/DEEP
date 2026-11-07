package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.feature.rewards.model.ListenOutcome
import kotlinx.serialization.Serializable
import retrofit2.http.Body
import retrofit2.http.POST
import java.time.Instant

/**
 * The listen report — `POST /me/sound/listens` (`routes/sound.ts`).
 *
 * A Retrofit service on the one shared client, not a call on the media client:
 * the server keys the award to the member's *local* day, so the report must
 * carry `X-Device-Timezone` and the bearer token like any other DEEP request.
 *
 * The reply is the award outcome, the day's track tally and the shared
 * `{ wallet, plant }` tail ([ListenResponseDto]). [reportListen] folds it into
 * a [ListenOutcome] for `ListenReporter`, which hands the grant to the shared
 * award ingest — iOS's `APIRewardsRemote.reportListen`.
 */
interface SoundListensService {

  @POST("me/sound/listens")
  suspend fun report(@Body body: ListenRequest): ListenResponseDto
}

/**
 * [completedAt] is when playback finished on the device — UTC ISO-8601 with
 * milliseconds ([wireTimestamp]), which the route's `datetime({ offset: true })`
 * accepts — so a listen retried after a network blip still counts on the day
 * it happened. Older builds omitted it, meaning "just now".
 */
@Serializable
data class ListenRequest(
  val trackId: String,
  val completedAt: String? = null,
)

/**
 * Reports one finished track. Throws [DeepApiException] for anything but an
 * answer — `ListenReporter` reads a 400, 403 (`premium_locked`) or 404 as
 * final and keeps the listen for anything else. A 2xx whose body can't be
 * read was still received, so it comes back as [ListenOutcome.Unjudged]
 * rather than being retried (iOS's `isFinal(APIError.decoding)`).
 */
suspend fun SoundListensService.reportListen(trackId: String, completedAt: Instant): ListenOutcome {
  val dto = try {
    apiCall { report(ListenRequest(trackId = trackId, completedAt = wireTimestamp(completedAt))) }
  } catch (unreadable: DeepApiException.Decoding) {
    return ListenOutcome.Unjudged
  }
  return dto.toDomain()
}
