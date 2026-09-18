package io.appbeyond.freelance.deep.auth

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Single-flight session rotation.
 *
 * This is the one piece of the networking layer that must be exactly right, and
 * the reason it lives in a plain Kotlin module with a test beside it rather than
 * inside an OkHttp `Authenticator`.
 *
 * deep-api rotates refresh tokens (`auth/sessions.ts`), and a token presented a
 * second time is read as theft: the session is revoked and the call comes back
 * `token_reuse`. So two concurrent refreshes do not merely waste a round trip —
 * the second one signs the member out. The app opens several requests at once on
 * every screen, and an expired access token 401s all of them together, so this
 * is the ordinary case, not a rare one.
 *
 * Two rules follow, both ported from `APIClient.refreshTokens()`:
 *
 * - **Exactly one call per wave.** The first caller through rotates. Everyone who
 *   arrives while that call is in flight waits on its outcome; everyone who
 *   arrives after it lands sees a stored access token that is no longer the one
 *   their request failed with, and simply uses it. Nobody presents the old
 *   refresh token twice.
 * - **Tokens are cleared only on an actual refusal.** A timeout, a dead host or a
 *   502 keeps the pair — see [isAuthRejection]. Clearing on those would sign the
 *   member out every time the backend blinked.
 *
 * @param tokens where the pair lives.
 * @param rotation the call that performs the exchange.
 */
class TokenRefresher(
  private val tokens: TokenStoring,
  private val rotation: TokenRefreshing,
) {

  private val mutex = Mutex()

  /**
   * The rotation currently in flight, shared by everyone who arrives during it.
   * Only ever touched under [mutex].
   */
  private var inFlight: CompletableDeferred<String>? = null

  /**
   * Returns an access token worth retrying with, rotating the session at most
   * once however many callers ask at the same moment.
   *
   * @param failedAccessToken the token the caller's request was rejected with,
   *   or null when it sent none. It is what distinguishes "my token is stale"
   *   from "somebody already fixed this for me": if the store no longer holds
   *   this token, the rotation has already happened and its result is returned
   *   without a call.
   *
   * @throws SessionEnded when the server refused the refresh token, or there was
   *   no session to refresh. Tokens are cleared; the member is signed out.
   * @throws Throwable the underlying failure, unchanged, for anything else. The
   *   session is untouched and the caller may try again later.
   */
  suspend fun refreshedAccessToken(failedAccessToken: String?): String =
    when (val claim = claimRotation(failedAccessToken)) {
      is Rotation.Settled -> claim.accessToken
      is Rotation.Following -> claim.pending.await()
      is Rotation.Leading -> rotate(claim.pending, claim.refreshToken)
    }

  /**
   * Decides, under the lock, which of the three things this caller is: too late
   * to matter, a passenger on someone else's call, or the one who makes it.
   *
   * Nothing suspends on I/O in here beyond reading the store, so the lock is
   * held for microseconds and the network call happens outside it.
   */
  private suspend fun claimRotation(failedAccessToken: String?): Rotation = mutex.withLock {
    val current = tokens.tokens() ?: throw SessionEnded("There is no session to refresh.")

    // The common case in a wave of 401s: somebody ahead of us already rotated,
    // so the token in the store is the answer and there is nothing to call.
    if (failedAccessToken != null && current.access != failedAccessToken) {
      return@withLock Rotation.Settled(current.access)
    }

    val existing = inFlight
    if (existing != null) return@withLock Rotation.Following(existing)

    val pending = CompletableDeferred<String>()
    inFlight = pending
    Rotation.Leading(pending, current.refresh)
  }

  /**
   * Makes the one call, and hands its outcome — success or failure — to everyone
   * waiting behind it.
   *
   * Sharing the *failure* matters as much as sharing the success. If a refresh
   * times out after the server has already rotated, a second attempt with the
   * same refresh token is precisely the reuse that revokes the session. The
   * passengers therefore fail with the leader rather than trying again.
   */
  private suspend fun rotate(pending: CompletableDeferred<String>, refreshToken: String): String {
    try {
      val rotated = rotation.refresh(refreshToken)
      tokens.save(rotated)
      pending.complete(rotated.access)
      return rotated.access
    } catch (cancelled: CancellationException) {
      pending.completeExceptionally(cancelled)
      throw cancelled
    } catch (failure: Throwable) {
      val surfaced =
        if (isAuthRejection(failure)) {
          tokens.clear()
          SessionEnded("The server refused this session's refresh token.", failure)
        } else {
          // Transport or server hiccup: keep the pair, surface the real error.
          failure
        }
      pending.completeExceptionally(surfaced)
      throw surfaced
    } finally {
      // NonCancellable because a cancelled coroutine cannot take a lock, and
      // leaving a completed rotation parked in `inFlight` would wedge every
      // later 401 onto a result that is already stale.
      withContext(NonCancellable) {
        mutex.withLock { if (inFlight === pending) inFlight = null }
      }
    }
  }

  /** What a caller turned out to be, decided under the lock. */
  private sealed interface Rotation {

    /** Someone else already rotated; the store's token is the answer. */
    class Settled(val accessToken: String) : Rotation

    /** A rotation is in flight; share its outcome, whatever it is. */
    class Following(val pending: CompletableDeferred<String>) : Rotation

    /** This caller owns the one call. */
    class Leading(val pending: CompletableDeferred<String>, val refreshToken: String) : Rotation
  }

  companion object {

    /**
     * Whether an error is the server refusing the credentials themselves — the
     * only failures that may end a session.
     *
     * Ported from `APIClient.isAuthRejection(_:)`. Transport errors, 5xx and
     * malformed responses are outages, not revocations, and a session survives
     * them.
     */
    fun isAuthRejection(error: Throwable): Boolean = when {
      error is SessionEnded -> true
      error is HttpStatusCarrying -> error.status in 400..499
      else -> false
    }
  }
}
