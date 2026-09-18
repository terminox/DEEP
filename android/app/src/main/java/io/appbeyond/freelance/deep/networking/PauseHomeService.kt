package io.appbeyond.freelance.deep.networking

import kotlinx.serialization.SerializationException
import retrofit2.HttpException
import retrofit2.http.GET
import java.io.IOException

/**
 * The Global Pause home endpoint.
 *
 * Paths are relative — `"pause/home"`, not `"/pause/home"` — because Retrofit
 * resolves them against a base URL that must end in a slash, while
 * `AppConfig.apiBaseUrl` deliberately ends without one so callers can append a
 * leading-slash path. `AppDependencies` adds the slash in exactly one place; a
 * leading slash here would silently discard any path component of the base URL.
 */
interface PauseHomeService {

  /**
   * No auth required. The route runs `optionalAuth` (`routes/pause.ts`), so a
   * signed-out member gets deterministic fallback shelves and a signed-in one
   * gets a personalized "Made for you" — from the same call, with the bearer
   * token the client attaches when there is one.
   */
  @GET("pause/home")
  suspend fun pauseHome(): PauseHomeDto
}

/**
 * What one attempt at the Global Pause home produced.
 *
 * A result rather than a thrown exception, because on this screen a failure is a
 * state to render — the retry cue — not an exceptional condition. The error
 * carries copy a screen can show verbatim; see [DeepApiException].
 */
sealed interface PauseHomeResult {

  data class Loaded(val home: PauseHomeDto) : PauseHomeResult

  data class Failed(val error: DeepApiException) : PauseHomeResult
}

/**
 * The seam between the Global Pause screens and the network.
 *
 * Its whole job is to turn the four ways a Retrofit call can fail into the one
 * error type the rest of the app understands. Nothing above it should ever have
 * to know that `HttpException` exists.
 */
class PauseHomeRepository(private val service: PauseHomeService) {

  suspend fun load(): PauseHomeResult =
    try {
      PauseHomeResult.Loaded(service.pauseHome())
    } catch (api: DeepApiException) {
      // Already ours — raised by the refresh path underneath.
      PauseHomeResult.Failed(api)
    } catch (http: HttpException) {
      // Reading the error body can itself fail, and losing the envelope must not
      // lose the status with it — `of` has copy for a body it cannot read.
      val body = runCatching { http.response()?.errorBody()?.string() }.getOrNull()
      PauseHomeResult.Failed(DeepApiException.of(http.code(), body))
    } catch (malformed: SerializationException) {
      PauseHomeResult.Failed(
        DeepApiException.Decoding(malformed.message ?: "Unexpected response", malformed)
      )
    } catch (offline: IOException) {
      PauseHomeResult.Failed(
        DeepApiException.Transport(offline.message ?: "Network error", offline)
      )
    }
}
