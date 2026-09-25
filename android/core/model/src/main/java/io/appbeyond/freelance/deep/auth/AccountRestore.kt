package io.appbeyond.freelance.deep.auth

/** What `GET /me` produced during launch restore, abstracted away from HTTP. */
sealed interface MeFetch {
  data class Fetched(val account: Account) : MeFetch
  /** 401 after the refresh path gave up, or any other 4xx. */
  data object Rejected : MeFetch
  /** Offline, timeout, 5xx, undecodable. */
  data object Unreachable : MeFetch
}

sealed interface RestoreOutcome {
  data object SignedOut : RestoreOutcome
  /** [cache] true → persist this account as the offline cache. */
  data class SignedIn(val account: Account, val cache: Boolean) : RestoreOutcome
}

/**
 * `APIAccountStore.restore()` as a pure decision:
 *  - no tokens → SignedOut ([fetch] is never consulted; pass null)
 *  - Fetched → SignedIn(account, cache = true)
 *  - Rejected → SignedOut (caller clears tokens + cache)
 *  - Unreachable → SignedIn(cached ?: Account.Placeholder, cache = false)
 */
fun resolveRestore(hasTokens: Boolean, fetch: MeFetch?, cached: Account?): RestoreOutcome {
  if (!hasTokens) return RestoreOutcome.SignedOut
  return when (fetch) {
    is MeFetch.Fetched -> RestoreOutcome.SignedIn(fetch.account, cache = true)
    MeFetch.Rejected -> RestoreOutcome.SignedOut
    MeFetch.Unreachable -> RestoreOutcome.SignedIn(cached ?: Account.Placeholder, cache = false)
    null -> RestoreOutcome.SignedOut
  }
}
