package io.appbeyond.freelance.deep.auth

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Single-flight session rotation, and the one writer of the token store.
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
 * Three rules follow. The first two are ported from `APIClient.refreshTokens()`:
 *
 * - **Exactly one call per wave.** The first caller through rotates. Everyone who
 *   arrives while that call is in flight waits on its outcome; everyone who
 *   arrives after it lands sees a stored access token that is no longer the one
 *   their request failed with, and simply uses it. Nobody presents the old
 *   refresh token twice.
 * - **Tokens are cleared only on an actual refusal.** A timeout, a dead host or a
 *   502 keeps the pair — see [isAuthRejection]. Clearing on those would sign the
 *   member out every time the backend blinked.
 * - **A rotation only settles the session it started from.** The network call
 *   runs outside the lock, so the member can log out, or log out and into a
 *   different account, while it is in flight. When it lands, the stored pair is
 *   re-read under the lock and the outcome is applied only if the refresh token
 *   is still the one that was presented — compare-and-set. Without that, a stale
 *   refusal clears the *new* session, or a stale success writes the old
 *   member's rotated pair over it. iOS gets this for free from `@MainActor`
 *   serialising the whole exchange; here it has to be explicit.
 *
 * The third rule only holds if every other write to the store takes the same
 * lock, which is why sign-in and sign-out go through [adopt] and [end] rather
 * than to [TokenStoring] directly.
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
   * Called when the server refuses this session's refresh token and the pair has
   * just been cleared — the involuntary sign-out.
   *
   * Runs under the lock, so it is ordered against [adopt] and [end]: a sign-in
   * that races it lands either wholly before (and then this is not called at
   * all, because the compare-and-set fails) or wholly after. The account store
   * installs it to drop its account and cache, which is what makes it, and not
   * the token store, the one authority on whether anyone is signed in.
   *
   * Must not call [adopt] or [end] — the lock is not reentrant — and should not
   * throw; a failure in it is swallowed so the session still ends.
   */
  @Volatile
  var onSessionEnded: suspend () -> Unit = {}

  /**
   * Starts a session: stores [pair], then runs [alongside] under the same lock.
   *
   * Sign-up and log-in come through here so a rotation of the *previous* session
   * that lands afterwards sees a different refresh token and leaves this one
   * alone. [alongside] is where the caller publishes the account, so the tokens
   * and the account the UI reads can never be observed out of step by a
   * concurrent [onSessionEnded].
   *
   * Once the lock is held, the writes complete even if the caller is cancelled —
   * half of a sign-in is worse than none.
   */
  suspend fun adopt(pair: TokenPair, alongside: suspend () -> Unit = {}) {
    mutex.withLock {
      withContext(NonCancellable) {
        tokens.save(pair)
        alongside()
      }
    }
  }

  /**
   * Ends the session on purpose — log out, delete account, a rejected restore.
   * Clears the pair, then runs [alongside] under the same lock. A rotation in
   * flight will find the store empty when it lands and discard its outcome.
   */
  suspend fun end(alongside: suspend () -> Unit = {}) {
    mutex.withLock {
      withContext(NonCancellable) {
        tokens.clear()
        alongside()
      }
    }
  }

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
   * @throws SessionEnded when the server refused the refresh token, there was no
   *   session to refresh, or the session this rotation started from was replaced
   *   or ended while it was in flight. In the refusal case the tokens are cleared
   *   and [onSessionEnded] has run; in the others the store is left exactly as
   *   the newer sign-in or sign-out wrote it.
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
  private suspend fun rotate(pending: CompletableDeferred<String>, presented: String): String {
    val outcome: Result<TokenPair> = try {
      Result.success(rotation.refresh(presented))
    } catch (cancelled: CancellationException) {
      // NonCancellable because a cancelled coroutine cannot take a lock, and
      // leaving an abandoned rotation parked in `inFlight` would wedge every
      // later 401 onto it.
      withContext(NonCancellable) { mutex.withLock { release(pending) } }
      pending.completeExceptionally(cancelled)
      throw cancelled
    } catch (failure: Throwable) {
      Result.failure(failure)
    }

    return try {
      // NonCancellable because once the server has answered, the answer must be
      // recorded: a rotated pair that is dropped on the floor leaves the store
      // holding a refresh token the server has already retired, and presenting
      // it next time is the reuse that revokes the session.
      val access = withContext(NonCancellable) {
        mutex.withLock {
          release(pending)
          settle(presented, outcome)
        }
      }
      pending.complete(access)
      access
    } catch (surfaced: Throwable) {
      pending.completeExceptionally(surfaced)
      throw surfaced
    }
  }

  /**
   * Applies a rotation's outcome — compare-and-set against the refresh token it
   * [presented]. Called under the lock.
   */
  private suspend fun settle(presented: String, outcome: Result<TokenPair>): String {
    val stillCurrent = tokens.tokens()?.refresh == presented

    val rotated = outcome.getOrElse { failure ->
      // Transport or server hiccup: keep the pair, surface the real error.
      if (!isAuthRejection(failure)) throw failure

      if (stillCurrent) {
        tokens.clear()
        try {
          onSessionEnded()
        } catch (cancelled: CancellationException) {
          throw cancelled
        } catch (_: Throwable) {
          // The tokens are gone either way; a handler that failed to tidy up
          // must not turn a sign-out into an outage.
        }
        throw SessionEnded("The server refused this session's refresh token.", failure)
      }
      // The refusal belongs to a session that is already over. Whatever the
      // store holds now — nothing, or somebody's newer sign-in — is not ours.
      throw SessionEnded("The session this refresh started from has already ended.", failure)
    }

    if (!stillCurrent) {
      // A sign-out or a new sign-in landed while the call was out. Writing this
      // pair would resurrect the old session or overwrite the new one; the
      // requests that asked for it belonged to the old one, so they end with it.
      throw SessionEnded("The session this refresh started from has already ended.")
    }

    tokens.save(rotated)
    return rotated.access
  }

  /** Forgets [pending] as the in-flight rotation. Called under the lock. */
  private fun release(pending: CompletableDeferred<String>) {
    if (inFlight === pending) inFlight = null
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
