package io.appbeyond.freelance.deep.feature.onboarding.store

import android.util.Log
import io.appbeyond.freelance.deep.auth.Account
import io.appbeyond.freelance.deep.auth.MeFetch
import io.appbeyond.freelance.deep.auth.RestoreOutcome
import io.appbeyond.freelance.deep.auth.TokenPair
import io.appbeyond.freelance.deep.auth.TokenRefresher
import io.appbeyond.freelance.deep.auth.TokenStoring
import io.appbeyond.freelance.deep.auth.resolveRestore
import io.appbeyond.freelance.deep.feature.premium.model.ServerEntitlement
import io.appbeyond.freelance.deep.networking.AuthResponseDto
import io.appbeyond.freelance.deep.networking.AuthService
import io.appbeyond.freelance.deep.networking.DeepApiException
import io.appbeyond.freelance.deep.networking.LogInRequestDto
import io.appbeyond.freelance.deep.networking.SignUpRequestDto
import io.appbeyond.freelance.deep.networking.apiCall
import io.appbeyond.freelance.deep.networking.toAccount
import io.appbeyond.freelance.deep.networking.toDomain
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * [AccountStore] backed by the DEEP backend. The Android twin of
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
 *   server rejects. The composition root resets onboarding progress and the
 *   rewards stores here, as Settings does after a voluntary log out, so the
 *   next person on this device never inherits the last member's answers,
 *   garden or hearts. Runs after [account] has gone null. Never runs for
 *   someone who was never signed in.
 * @param identitySink hears the DEEP user id whenever a member is signed in
 *   (sign-up, login, launch — the cached id when launch is offline) and null
 *   whenever a session ends (log out, deletion, a rejected session). The
 *   composition root points it at DEEP Premium's store and access, so this
 *   store never learns RevenueCat exists — iOS's `identitySink`. Runs in the
 *   same step as [account] moves, so it never lags behind it.
 * @param entitlementSink hears the DEEP Premium answer the server sends
 *   beside the member on `/me`, sign-up and login, after [identitySink] has
 *   heard who it is for. Passed along unread — this store decides nothing
 *   about premium. Null from an older server.
 */
class ApiAccountStore(
  private val auth: AuthService,
  private val tokens: TokenStoring,
  private val refresher: TokenRefresher,
  private val cache: AccountCache,
  private val onInvoluntarySignOut: suspend () -> Unit = {},
  private val identitySink: suspend (String?) -> Unit = {},
  private val entitlementSink: suspend (ServerEntitlement?) -> Unit = {},
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
          // forgetLocally told the sink only if this store held an account;
          // a launch that held none still has to say "nobody", or a store
          // configured for the last member would keep speaking for them.
          bestEffort("report a signed-out launch") { identitySink(null) }
          // Tokens on disk means somebody had signed in on this device; the
          // server has now said that session is over. Nobody had, and there is
          // an anonymous member's onboarding in progress worth keeping.
          if (hasTokens) bestEffort("reset onboarding after a rejected restore") { onInvoluntarySignOut() }
        }
        is RestoreOutcome.SignedIn -> {
          _account.value = outcome.account
          // The placeholder an offline launch with no cache stands in has no
          // id to report — iOS reports nothing then, too.
          if (outcome.account.id.isNotEmpty()) {
            bestEffort("report the restored member") { identitySink(outcome.account.id) }
          }
          if (outcome.cache) bestEffort("cache the restored account") { cache.write(outcome.account) }
          if (fetch is MeFetch.Fetched) {
            bestEffort("pass on the DEEP Premium answer") { entitlementSink(fetch.entitlement) }
          }
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
      apiCall { auth.me() }.let { me -> MeFetch.Fetched(me.user.toAccount(), me.entitlement?.toDomain()) }
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
      bestEffort("report the signed-in member") { identitySink(account.id) }
      bestEffort("cache the signed-in account") { cache.write(account) }
    }
    bestEffort("pass on the DEEP Premium answer") { entitlementSink(response.entitlement?.toDomain()) }
    return account
  }

  /**
   * The DEEP user id of the last signed-in member, straight from the offline
   * cache — available at launch before [restore] has asked the server, so
   * DEEP Premium's store can start out speaking for the right member. iOS's
   * `lastKnownUserID`. Null when nobody is cached, or the read fails.
   */
  suspend fun lastKnownUserId(): String? =
    try {
      cache.read()?.id?.takeIf { it.isNotEmpty() }
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (_: Exception) {
      null
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
    val hadAccount = _account.value != null
    _account.value = null
    if (hadAccount) bestEffort("report the session's end") { identitySink(null) }
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
