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
 * a state to render — the retry cue — not an exceptional condition.
 *
 * It also keeps the last feed it fetched, for the life of the process — DEEP
 * Sound's `cachedShelves`. The home screen is rebuilt every time Home's root
 * comes back (from a pushed collection, or another tab), and iOS's view, which
 * stays alive under the push, never shows its skeleton again once it has a
 * feed. Opening on [cached] does the same here: no skeleton, no flash, and
 * rows for the restored scroll position to land on, while a silent reload
 * runs behind it.
 */
class PauseHomeRepository(private val service: PauseHomeService) {

  /** A feed and the account it was fetched for. */
  private data class Cached(val key: Any?, val home: PauseHomeDto)

  @Volatile private var last: Cached? = null

  /**
   * The feed the last successful [load] for [key] returned this run, or null.
   * Keyed like the screen's load — by the signed-in account — so a member who
   * has just switched never opens on the previous one's "Made for you".
   */
  fun cached(key: Any?): PauseHomeDto? = last?.takeIf { it.key == key }?.home

  suspend fun load(key: Any? = null): PauseHomeResult =
    try {
      val home = apiCall { service.pauseHome() }
      last = Cached(key, home)
      PauseHomeResult.Loaded(home)
    } catch (api: DeepApiException) {
      PauseHomeResult.Failed(api)
    }
}
