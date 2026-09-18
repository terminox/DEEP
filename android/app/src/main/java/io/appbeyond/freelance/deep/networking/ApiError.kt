package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.auth.HttpStatusCarrying
import kotlinx.serialization.Serializable

/**
 * Errors surfaced by the networking layer, ported from `APIError.swift`.
 *
 * [message] carries the backend's gentle, user-facing copy where one exists, and
 * Deep's own where it does not — so a screen shows `error.message` verbatim and
 * never has to invent a sentence. That is the whole contract: **the message IS
 * the display string.** The technical detail lives beside it, in `detail` or the
 * `cause`, for logs.
 *
 * Every success from deep-api is HTTP 200 and every failure is
 * `{ "error": { "code", "message" } }` (`app.ts`), which is what [of] reads.
 *
 * The 4xx cases implement [HttpStatusCarrying] so `TokenRefresher` in `:core:model`
 * can tell a revoked session from an outage without knowing what HTTP is.
 */
sealed class DeepApiException(
  override val message: String,
  cause: Throwable? = null,
) : Exception(message, cause) {

  /** Not authenticated / refresh failed — the caller should treat as signed out. */
  class Unauthorized(cause: Throwable? = null) :
    DeepApiException("Your session has ended. Please sign in again.", cause),
    HttpStatusCarrying {
    override val status: Int = 401
  }

  /** A non-2xx response carrying the backend's `{ error: { code, message } }`. */
  class Http(
    override val status: Int,
    val code: String,
    serverMessage: String,
  ) : DeepApiException(serverMessage), HttpStatusCarrying

  /**
   * Transport failure (offline, timeout, DNS, a Mac that went to sleep).
   *
   * Never an auth rejection: a session survives every one of these.
   */
  class Transport(val detail: String, cause: Throwable? = null) :
    DeepApiException(
      "We couldn't reach DEEP just now. Check your connection and try again.",
      cause,
    )

  /** Response body didn't match the expected shape. */
  class Decoding(val detail: String, cause: Throwable? = null) :
    DeepApiException("Something looked off in the response. Please try again.", cause)

  companion object {

    /**
     * Turns a non-2xx response into the exception a screen can show.
     *
     * Ported from `APIClient.apiError(from:status:)`, including the fallback
     * copy for a body that is not the envelope — a proxy's HTML error page, or
     * an empty 502 from Cloud Run while a revision rolls.
     */
    fun of(status: Int, body: String?): DeepApiException {
      if (status == 401) return Unauthorized()

      val envelope = body
        ?.takeIf { it.isNotBlank() }
        ?.let { text ->
          runCatching { DeepJson.decodeFromString(ErrorEnvelope.serializer(), text) }.getOrNull()
        }

      return if (envelope != null) {
        Http(status = status, code = envelope.error.code, serverMessage = envelope.error.message)
      } else {
        Http(status = status, code = "http_$status", serverMessage = "Request failed ($status).")
      }
    }
  }
}

/** The failure envelope every deep-api error handler writes (`app.ts`). */
@Serializable
private data class ErrorEnvelope(val error: Body) {

  @Serializable
  data class Body(val code: String, val message: String)
}
