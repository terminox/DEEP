package io.appbeyond.freelance.deep.feature.onboarding.store

import android.util.Log
import io.appbeyond.freelance.deep.auth.Account
import io.appbeyond.freelance.deep.auth.MeFetch
import io.appbeyond.freelance.deep.auth.RestoreOutcome
import io.appbeyond.freelance.deep.auth.TokenPair
import io.appbeyond.freelance.deep.auth.TokenRefresher
import io.appbeyond.freelance.deep.auth.TokenStoring
import io.appbeyond.freelance.deep.auth.resolveRestore
import io.appbeyond.freelance.deep.networking.AuthResponseDto
import io.appbeyond.freelance.deep.networking.AuthService
import io.appbeyond.freelance.deep.networking.DeepApiException
import io.appbeyond.freelance.deep.networking.LogInRequestDto
import io.appbeyond.freelance.deep.networking.SignUpRequestDto
import io.appbeyond.freelance.deep.networking.apiCall
import io.appbeyond.freelance.deep.networking.toAccount
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * [AccountStore] backed by the Deep backend. The Android twin of
 * `APIAccountStore.swift`: this store keeps only the (non-secret) [Account]
 * identity for the UI, mirrored into [cache] so an offline launch can restore
 * the signed-in shell without the network.
 *
 * It is the one authority on whether anyone is signed in — the root phase reads
 * [account] and nothing else — so every way a session ends has to arrive here,
 * including the ones the member didn't ask for. That is why it installs itself
 * as [TokenRefresher.onSessionEnded]: when the server refuses the refresh token
 * mid-session, the refresher clears the pair and this store drops the account
 * in the same locked step, and the root falls back to the flow on its own.
 * Without it, the shell stays mounted over an empty token store and every call
 * 401s. iOS gets the same effect from `APIClient` posting its session-ended
 * notification to `APIAccountStore`.
 *
 * Token writes go through [refresher] ([TokenRefresher.adopt] /
 * [TokenRefresher.end]) rather than to [tokens] directly, so a rotation of the
 * previous session that lands late can't clear or overwrite this one. [tokens]
 * is only read.
 *
 * @param onInvoluntarySignOut runs after a signed-in session is ended by the
 *   server rather than by the member — a refused refresh, or a restore the
 *   server rejects. The composition root resets onboarding progress here, as
 *   Settings does after a voluntary log out, so the next person on this device
 *   never inherits the last member's answers. Never runs for someone who was
 *   never signed in.
 */
class ApiAccountStore(
  private val auth: AuthService,
  private val tokens: TokenStoring,
  private val refresher: TokenRefresher,
  private val cache: AccountCache,
  private val onInvoluntarySignOut: suspend () -> Unit = {},
) : AccountStore {

  private val _account = MutableStateFlow<Account?>(null)
  override val account: StateFlow<Account?> = _account.asStateFlow()

  init {
    refresher.onSessionEnded = {
      forgetLocally()
      bestEffort("reset onboarding after the session ended") { onInvoluntarySignOut() }
    }
  }

  override suspend fun restore() {
    try {
      val hasTokens = tokens.tokens() != null
      val cached = cache.read()
      val fetch = if (hasTokens) fetchMe() else null

      when (val outcome = resolveRestore(hasTokens = hasTokens, fetch = fetch, cached = cached)) {
        RestoreOutcome.SignedOut -> {
          refresher.end { forgetLocally() }
          // Tokens on disk means somebody had signed in on this device; the
          // server has now said that session is over. Nobody had, and there is
          // an anonymous member's onboarding in progress worth keeping.
          if (hasTokens) bestEffort("reset onboarding after a rejected restore") { onInvoluntarySignOut() }
        }
        is RestoreOutcome.SignedIn -> {
          _account.value = outcome.account
          if (outcome.cache) bestEffort("cache the restored account") { cache.write(outcome.account) }
        }
      }
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (unexpected: Exception) {
      // The contract is "never throws": launch waits on this, and an escape
      // would hold the breathing beat forever. Whatever [account] holds now
      // stands — null, most likely, which lands the member in the flow.
      Log.w(TAG, "Restore failed; continuing with the account as it stands.", unexpected)
    }
  }

  /** `GET /me`, abstracted into the pure [MeFetch] vocabulary [resolveRestore] decides on. */
  private suspend fun fetchMe(): MeFetch =
    try {
      MeFetch.Fetched(apiCall { auth.me() }.user.toAccount())
    } catch (rejected: DeepApiException) {
      when {
        rejected is DeepApiException.Unauthorized -> MeFetch.Rejected
        rejected is DeepApiException.Http && rejected.status in 400..499 -> MeFetch.Rejected
        else -> MeFetch.Unreachable
      }
    }

  override suspend fun signUp(displayName: String, email: String, password: String): Account =
    adopt(apiCall { auth.signUp(SignUpRequestDto(email = email, password = password, displayName = displayName)) })

  override suspend fun logIn(email: String, password: String): Account =
    adopt(apiCall { auth.logIn(LogInRequestDto(email = email, password = password)) })

  override suspend fun logOut() {
    runCatching { apiCall { auth.logOut() } }
    refresher.end { forgetLocally() }
  }

  override suspend fun deleteAccount() {
    // First, and un-caught: if this throws, nothing below it runs and the
    // member stays signed in with everything intact to retry.
    apiCall { auth.deleteMe() }
    refresher.end { forgetLocally() }
  }

  private suspend fun adopt(response: AuthResponseDto): Account {
    val account = response.user.toAccount()
    refresher.adopt(TokenPair(access = response.accessToken, refresh = response.refreshToken)) {
      // Published in the same locked step as the tokens, so a late refusal of
      // the previous session can't land between the two and null this account.
      _account.value = account
      bestEffort("cache the signed-in account") { cache.write(account) }
    }
    return account
  }

  /**
   * Drops the account and its offline copy. Runs under the refresher's lock
   * (inside [TokenRefresher.end] or as [TokenRefresher.onSessionEnded]), so it
   * must not call back into the refresher.
   *
   * The account is nulled first: that is what the UI reads, and a cache that
   * failed to clear only costs a stale name on a later offline launch — one a
   * token-less restore clears again anyway.
   */
  private suspend fun forgetLocally() {
    _account.value = null
    bestEffort("clear the cached account") { cache.clear() }
  }

  /**
   * The cache is a convenience for offline launches, never a reason to fail a
   * sign-in, a sign-out or a restore: a DataStore I/O error is logged and
   * dropped.
   */
  private suspend fun bestEffort(what: String, block: suspend () -> Unit) {
    try {
      block()
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (failure: Exception) {
      Log.w(TAG, "Could not $what.", failure)
    }
  }

  private companion object {
    const val TAG = "ApiAccountStore"
  }
}
