package io.appbeyond.freelance.deep.networking

import kotlinx.serialization.SerializationException
import retrofit2.HttpException
import java.io.IOException

/**
 * Runs one Retrofit call and turns every way it can fail into [DeepApiException],
 * so nothing above this layer ever has to know that Retrofit, OkHttp or kotlinx
 * serialization exist. Shared by every repository and store that talks to
 * deep-api — [PauseHomeRepository] and the account and onboarding stores — so
 * this four-way catch is written exactly once.
 *
 * A [DeepApiException] raised from inside [block] — most often by the token
 * refresh path underneath a Retrofit call — passes through unchanged.
 */
suspend fun <T> apiCall(block: suspend () -> T): T =
  try {
    block()
  } catch (api: DeepApiException) {
    throw api
  } catch (http: HttpException) {
    // Reading the error body can itself fail, and losing the envelope must not
    // lose the status with it — `DeepApiException.of` has copy for a body it
    // cannot read.
    val body = runCatching { http.response()?.errorBody()?.string() }.getOrNull()
    throw DeepApiException.of(http.code(), body)
  } catch (malformed: SerializationException) {
    throw DeepApiException.Decoding(malformed.message ?: "Unexpected response", malformed)
  } catch (offline: IOException) {
    throw DeepApiException.Transport(offline.message ?: "Network error", offline)
  }
