package io.appbeyond.freelance.deep.auth

import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.net.SocketTimeoutException
import java.util.concurrent.atomic.AtomicInteger
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

/**
 * The suite that earns [TokenRefresher] its module boundary.
 *
 * There is no iOS counterpart to port: `APIClient.refreshTokens()` is
 * `@MainActor`, wrapped around `URLSession`, and its single-flight behaviour is
 * therefore only observable against a live server. Here the rotation is a plain
 * suspend function over two interfaces, so the thing that actually matters — that
 * twenty simultaneous 401s produce exactly *one* call to `/auth/refresh` — is
 * asserted directly, on virtual time, in about a millisecond.
 *
 * It matters because deep-api revokes the entire session when a refresh token is
 * presented twice (`auth/sessions.ts`: "Reuse of the previous (already-rotated)
 * token => compromise. Kill it."). A second concurrent refresh is not a wasted
 * round trip; it is a forced sign-out.
 */
class TokenRefresherTest {

  @Test
  @DisplayName("twenty concurrent 401s rotate the session exactly once")
  fun singleFlight() = runTest {
    val store = FakeTokenStore(TokenPair(access = "access-stale", refresh = "refresh-1"))
    val endpoint = CountingTokenRefresh {
      // Long enough that every one of the twenty piles up behind the leader,
      // which is the situation this whole class exists for.
      delay(50)
      TokenPair(access = "access-fresh", refresh = "refresh-2")
    }
    val refresher = TokenRefresher(store, endpoint)

    val results = (1..20)
      .map { async { refresher.refreshedAccessToken("access-stale") } }
      .awaitAll()

    assertEquals(
      1,
      endpoint.calls,
      "Twenty callers must produce one refresh. A second one presents the " +
        "already-rotated token and deep-api revokes the session.",
    )
    assertEquals(listOf("refresh-1"), endpoint.presented)
    assertEquals(List(20) { "access-fresh" }, results, "Every caller gets the rotated token.")
    assertEquals(TokenPair(access = "access-fresh", refresh = "refresh-2"), store.stored)
  }

  @Test
  @DisplayName("a caller whose token was already replaced never calls the endpoint")
  fun latecomerReusesTheStoredToken() = runTest {
    val store = FakeTokenStore(TokenPair(access = "access-fresh", refresh = "refresh-2"))
    val endpoint = CountingTokenRefresh { TokenPair("never", "never") }
    val refresher = TokenRefresher(store, endpoint)

    val token = refresher.refreshedAccessToken(failedAccessToken = "access-stale")

    assertEquals("access-fresh", token)
    assertEquals(0, endpoint.calls)
  }

  @Test
  @DisplayName("a refusal of the refresh token ends the session")
  fun rejectionClearsTokens() = runTest {
    val store = FakeTokenStore(TokenPair(access = "access-stale", refresh = "refresh-1"))
    val endpoint = CountingTokenRefresh { throw RefusedByServer(status = 401, code = "token_reuse") }
    val refresher = TokenRefresher(store, endpoint)

    assertFailsWith<SessionEnded> { refresher.refreshedAccessToken("access-stale") }

    assertNull(store.stored, "A refused refresh token is a dead session.")
    assertEquals(1, store.clears)
  }

  @Test
  @DisplayName("a timeout keeps the session: a blip is not a revocation")
  fun timeoutKeepsTokens() = runTest {
    val stored = TokenPair(access = "access-stale", refresh = "refresh-1")
    val store = FakeTokenStore(stored)
    val endpoint = CountingTokenRefresh { throw SocketTimeoutException("timeout") }
    val refresher = TokenRefresher(store, endpoint)

    assertFailsWith<SocketTimeoutException> { refresher.refreshedAccessToken("access-stale") }

    assertEquals(stored, store.stored, "An unreachable host must not sign anyone out.")
    assertEquals(0, store.clears)
  }

  @Test
  @DisplayName("a 502 keeps the session too")
  fun serverErrorKeepsTokens() = runTest {
    val stored = TokenPair(access = "access-stale", refresh = "refresh-1")
    val store = FakeTokenStore(stored)
    val endpoint = CountingTokenRefresh { throw RefusedByServer(status = 502, code = "bad_gateway") }
    val refresher = TokenRefresher(store, endpoint)

    assertFailsWith<RefusedByServer> { refresher.refreshedAccessToken("access-stale") }

    assertEquals(stored, store.stored)
    assertEquals(0, store.clears)
  }

  @Test
  @DisplayName("no stored session is already a signed-out one")
  fun emptyStoreEndsTheSession() = runTest {
    val store = FakeTokenStore(null)
    val endpoint = CountingTokenRefresh { TokenPair("never", "never") }
    val refresher = TokenRefresher(store, endpoint)

    assertFailsWith<SessionEnded> { refresher.refreshedAccessToken("access-stale") }

    assertEquals(0, endpoint.calls)
  }

  @Test
  @DisplayName("the twenty behind a failed rotation share its failure rather than retrying")
  fun failureIsSharedAcrossTheWave() = runTest {
    val store = FakeTokenStore(TokenPair(access = "access-stale", refresh = "refresh-1"))
    val endpoint = CountingTokenRefresh {
      delay(50)
      throw SocketTimeoutException("timeout")
    }
    val refresher = TokenRefresher(store, endpoint)

    val outcomes = (1..20)
      .map {
        async {
          runCatching { refresher.refreshedAccessToken("access-stale") }
        }
      }
      .awaitAll()

    assertEquals(
      1,
      endpoint.calls,
      "A lost response may mean the server rotated anyway. Retrying with the " +
        "same refresh token is the reuse that revokes the session.",
    )
    assertEquals(20, outcomes.count { it.isFailure })
  }
}

/** An in-memory stand-in for the Keystore-backed store. */
private class FakeTokenStore(initial: TokenPair?) : TokenStoring {

  var stored: TokenPair? = initial
    private set

  var clears: Int = 0
    private set

  override suspend fun tokens(): TokenPair? = stored

  override suspend fun save(tokens: TokenPair) {
    stored = tokens
  }

  override suspend fun clear() {
    stored = null
    clears += 1
  }
}

/** Counts how many times the endpoint was actually reached, and with what. */
private class CountingTokenRefresh(
  private val respond: suspend (String) -> TokenPair,
) : TokenRefreshing {

  private val counter = AtomicInteger(0)
  private val seen = mutableListOf<String>()

  val calls: Int get() = counter.get()
  val presented: List<String> get() = seen.toList()

  override suspend fun refresh(refreshToken: String): TokenPair {
    counter.incrementAndGet()
    seen += refreshToken
    return respond(refreshToken)
  }
}

/**
 * What `DeepApiException.Http` looks like from this module: a failure carrying
 * the status the server answered with, and nothing else.
 */
private class RefusedByServer(
  override val status: Int,
  val code: String,
) : Exception("$code ($status)"), HttpStatusCarrying
