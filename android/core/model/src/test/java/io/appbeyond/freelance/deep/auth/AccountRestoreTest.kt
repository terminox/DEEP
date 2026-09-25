package io.appbeyond.freelance.deep.auth

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

/** Ported from `APIAccountStore.restore()` as a pure decision. */
class AccountRestoreTest {

  private val fetched = Account(id = "1", email = "mali@example.com", displayName = "Mali")
  private val cached = Account(id = "1", email = "mali@example.com", displayName = "Mali (cached)")

  @Test
  @DisplayName("no tokens is always SignedOut, and the fetch is never consulted")
  fun noTokens() {
    val outcome = resolveRestore(hasTokens = false, fetch = null, cached = cached)

    assertEquals(RestoreOutcome.SignedOut, outcome)
  }

  @Test
  @DisplayName("a fetched account signs in and caches it")
  fun fetched() {
    val outcome = resolveRestore(hasTokens = true, fetch = MeFetch.Fetched(fetched), cached = cached)

    assertEquals(RestoreOutcome.SignedIn(fetched, cache = true), outcome)
  }

  @Test
  @DisplayName("a rejection signs out, even with a cached account on hand")
  fun rejected() {
    val outcome = resolveRestore(hasTokens = true, fetch = MeFetch.Rejected, cached = cached)

    assertEquals(RestoreOutcome.SignedOut, outcome)
  }

  @Test
  @DisplayName("unreachable keeps the session on the cached account, without re-caching it")
  fun unreachableWithCache() {
    val outcome = resolveRestore(hasTokens = true, fetch = MeFetch.Unreachable, cached = cached)

    assertEquals(RestoreOutcome.SignedIn(cached, cache = false), outcome)
  }

  @Test
  @DisplayName("unreachable with nothing cached falls back to the placeholder")
  fun unreachableWithoutCache() {
    val outcome = resolveRestore(hasTokens = true, fetch = MeFetch.Unreachable, cached = null)

    assertEquals(RestoreOutcome.SignedIn(Account.Placeholder, cache = false), outcome)
  }
}
