package io.appbeyond.freelance.deep.auth

/**
 * The one call that exchanges a refresh token for a fresh pair.
 *
 * A capability rather than a client: [TokenRefresher] coordinates *when* a
 * rotation happens and how many of them happen at once, and knows nothing about
 * HTTP. The `:app` conformer POSTs `/auth/refresh` on a client with no
 * authenticator; a test conformer counts how many times it was asked.
 *
 * Implementations signal a refusal of the credentials by throwing something that
 * is [HttpStatusCarrying] with a 4xx status. Anything else thrown — a timeout, a
 * dead host, a 502 — is read as an outage and leaves the session intact.
 */
interface TokenRefreshing {
  suspend fun refresh(refreshToken: String): TokenPair
}

/**
 * A failure that carries the status the server answered with.
 *
 * The seam that lets [TokenRefresher.isAuthRejection] tell a revoked session
 * from a bad night on the train without this module knowing what HTTP is. The
 * transport's own error type in `:app` implements it; so does the fake in the
 * tests.
 */
interface HttpStatusCarrying {
  val status: Int
}

/**
 * The session is over: the server refused the refresh token itself, or there was
 * nothing stored to refresh with.
 *
 * Tokens have already been cleared by the time this is thrown. It is the only
 * failure out of [TokenRefresher] that means "sign the member out" — every other
 * one means "try again later, the session is still good".
 */
class SessionEnded(
  message: String,
  cause: Throwable? = null,
) : Exception(message, cause)
