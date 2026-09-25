package io.appbeyond.freelance.deep.networking

import retrofit2.http.GET

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
 * A thin wrapper over [apiCall]: the load comes back as a [PauseHomeResult]
 * rather than a thrown [DeepApiException], because on this screen a failure is
 * a state to render — the retry cue — not an exceptional condition. The error
 * carries copy a screen can show verbatim; see [DeepApiException].
 */
class PauseHomeRepository(private val service: PauseHomeService) {

  suspend fun load(): PauseHomeResult =
    try {
      PauseHomeResult.Loaded(apiCall { service.pauseHome() })
    } catch (api: DeepApiException) {
      PauseHomeResult.Failed(api)
    }
}
