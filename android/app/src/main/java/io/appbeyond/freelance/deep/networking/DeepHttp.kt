package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.auth.SessionEnded
import io.appbeyond.freelance.deep.auth.TokenPair
import io.appbeyond.freelance.deep.auth.TokenRefresher
import io.appbeyond.freelance.deep.auth.TokenRefreshing
import io.appbeyond.freelance.deep.auth.TokenStoring
import io.appbeyond.freelance.deep.shared.localization.AppLanguage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.Authenticator
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.Route
import okhttp3.logging.HttpLoggingInterceptor
import java.io.IOException
import java.util.TimeZone
import java.util.concurrent.TimeUnit

/**
 * The app's single HTTP seam to the Deep backend — the Android twin of
 * `APIClient.swift`.
 *
 * It owns one [OkHttpClient] carrying everything every Deep request needs: the
 * two ambient headers, the bearer token, fail-fast timeouts, and a transparent
 * refresh-then-retry on a 401. Retrofit services and Coil both ride on it, so
 * the app has one connection pool, one DNS and TLS cache, and one place these
 * headers are attached.
 *
 * @param baseUrl from `AppConfig.apiBaseUrl`, without a trailing slash.
 * @param tokens the session store. Read on every request, rotated by [tokenRefresher].
 * @param language the member's in-app language choice — **not** the system
 *   locale. Supplied as a lambda so the choice can change mid-session without
 *   rebuilding the client.
 * @param timeZoneId the device's IANA zone, likewise read per request: a member
 *   who flies gets the right day boundary without a relaunch.
 * @param logRequests wire logging, for the Dev flavor only.
 */
class DeepHttp(
  baseUrl: String,
  tokens: TokenStoring,
  json: Json = DeepJson,
  language: () -> AppLanguage,
  timeZoneId: () -> String = { TimeZone.getDefault().id },
  logRequests: Boolean = false,
) {

  /** The client every repository and every Retrofit service makes its calls on. */
  val client: OkHttpClient

  /**
   * The one place a session is rotated, shared by the authenticator and by
   * anything else that needs a live access token.
   */
  val tokenRefresher: TokenRefresher

  init {
    // The knot: the client needs an authenticator, the authenticator needs the
    // refresher, and the refresher needs a client derived from the client. It is
    // tied here by handing the authenticator its refresher a few lines after the
    // client is built — which is still long before the client makes a call.
    val authenticator = SessionAuthenticator()

    client = OkHttpClient.Builder()
      // Fail fast instead of the platform default, exactly as
      // `APIClient.makeSession()` does. Every flow in the app is best-effort
      // with a foreground retry, so a dead host should surface in seconds —
      // critical for device Dev builds pointing at a Mac that may be asleep,
      // but sane in production too.
      .connectTimeout(CONNECT_READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
      .readTimeout(CONNECT_READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
      .writeTimeout(CONNECT_READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
      // The ceiling on a whole call including redirects and the 401 retry —
      // the twin of `timeoutIntervalForResource`.
      .callTimeout(CALL_TIMEOUT_SECONDS, TimeUnit.SECONDS)
      .addInterceptor(DeepHeaders(language, timeZoneId))
      .addInterceptor(BearerToken(tokens))
      .apply {
        // Added last so it logs the headers the two interceptors above just
        // attached, rather than the bare request.
        if (logRequests) addInterceptor(wireLog())
      }
      .authenticator(authenticator)
      .build()

    // The refresh call goes out on its own client, built from this one so it
    // shares the connection pool and dispatcher — `newBuilder()` copies both by
    // reference — but with no authenticator at all. Without that, a refusal of
    // the refresh token would come back as a 401, re-enter the authenticator,
    // and refresh in order to refresh: an unbounded recursion that holds a
    // dispatcher thread for every turn of it.
    //
    // It keeps the interceptors, which is wanted: the refresh call should carry
    // the same timezone and language headers as any other. The stale bearer
    // token it also carries is inert — `/auth/refresh` has no auth preHandler
    // and reads its token from the body (`routes/auth.ts`).
    val refreshClient = client.newBuilder().authenticator(Authenticator.NONE).build()

    tokenRefresher = TokenRefresher(tokens, AuthRefreshEndpoint(refreshClient, baseUrl, json))
    authenticator.refresher = tokenRefresher
  }

  private companion object {
    const val CONNECT_READ_TIMEOUT_SECONDS = 10L
    const val CALL_TIMEOUT_SECONDS = 30L
  }
}

/** Request/response lines for the Dev flavor, with the token redacted. */
private fun wireLog(): HttpLoggingInterceptor =
  HttpLoggingInterceptor().apply {
    level = HttpLoggingInterceptor.Level.BASIC
    // Tokens are the one thing that must never reach logcat, where any app with
    // READ_LOGS on a rooted device can read them back.
    redactHeader("Authorization")
  }

/**
 * The two headers every Deep request carries, whether it is authorized or not.
 *
 * The user's day boundary travels with every request: award day-keys and "earned
 * today" figures follow the device timezone server-side. The language travels
 * too, so server-authored copy — track and collection titles, plant names, the
 * pause's welcome lines — arrives in the language the member picked in-app
 * rather than the one their phone is set to.
 */
private class DeepHeaders(
  private val language: () -> AppLanguage,
  private val timeZoneId: () -> String,
) : Interceptor {

  override fun intercept(chain: Interceptor.Chain): Response {
    val request = chain.request().newBuilder()
      .header("X-Device-Timezone", timeZoneId())
      .header("Accept-Language", language().acceptLanguageHeader)
      .build()
    return chain.proceed(request)
  }
}

/**
 * Attaches `Authorization: Bearer <access>` whenever a session exists.
 *
 * Unconditional on purpose. Routes that require auth need it; routes that merely
 * *tolerate* it get better answers with it — `/pause/home` runs `optionalAuth`
 * and returns a personalized "Made for you" only when a valid token is present
 * (`routes/pause.ts`). Routes that ignore it, like `/auth/login`, are unharmed.
 *
 * A request that already carries the header keeps it: that is how the retry the
 * authenticator builds survives this interceptor unchanged.
 *
 * [runBlocking] is deliberate. Interceptors are a blocking API, and the store
 * answers from an in-memory cache after its first read, so this parks an OkHttp
 * dispatcher thread for a field access rather than for I/O.
 */
private class BearerToken(private val tokens: TokenStoring) : Interceptor {

  override fun intercept(chain: Interceptor.Chain): Response {
    val request = chain.request()
    if (request.header("Authorization") != null) return chain.proceed(request)

    val access = runBlocking { tokens.tokens()?.access }
      ?: return chain.proceed(request)

    return chain.proceed(
      request.newBuilder().header("Authorization", "Bearer $access").build()
    )
  }
}

/**
 * Turns a 401 into one refresh and one retry, by adapting [TokenRefresher] to
 * OkHttp's blocking [Authenticator] contract.
 *
 * All of the hard thinking — how many refreshes a wave of 401s is allowed to
 * produce, and which failures may end a session — lives in `:core:model` where
 * it is unit-tested. This class only translates.
 */
private class SessionAuthenticator : Authenticator {

  /**
   * Set once by `DeepHttp.init`, immediately after the client is built and long
   * before it has made a single call. A `lateinit` rather than a lambda because
   * it makes the one-shot nature of the assignment visible.
   */
  lateinit var refresher: TokenRefresher

  override fun authenticate(route: Route?, response: Response): Request? {
    // Nothing to rotate if we never sent a token: an anonymous 401 is a real
    // 401 and belongs to the caller.
    val failed = response.request.header("Authorization")
      ?.removePrefix("Bearer ")
      ?.trim()
      ?.takeIf { it.isNotEmpty() }
      ?: return null

    // One attempt per call. OkHttp re-enters here for every 401 it receives, so
    // without this a server that also rejects the fresh token would loop.
    if (response.priorResponse != null) return null

    val access = try {
      runBlocking { refresher.refreshedAccessToken(failed) }
    } catch (ended: SessionEnded) {
      // The request's session is over — refused by the server (tokens cleared,
      // account store already signed out) or replaced by a newer sign-in or
      // sign-out mid-flight. Letting the 401 stand is what tells the caller.
      return null
    } catch (offline: IOException) {
      // Not a revocation — a blip. Failing the call as a transport error rather
      // than a 401 is what stops a dead Wi-Fi from reading as a sign-out.
      throw offline
    } catch (failure: Throwable) {
      throw IOException("Could not refresh the session: ${failure.message}", failure)
    }

    // The store handed back the token we already tried. Retrying it would just
    // 401 again.
    if (access == failed) return null

    return response.request.newBuilder()
      .header("Authorization", "Bearer $access")
      .build()
  }
}

/**
 * `POST /auth/refresh` on the authenticator-free client.
 *
 * Hand-rolled rather than a Retrofit service, because the client it must run on
 * is derived from the one Retrofit itself is built with — and because keeping it
 * here puts the call and the reason it is isolated in the same file.
 */
private class AuthRefreshEndpoint(
  private val client: OkHttpClient,
  private val baseUrl: String,
  private val json: Json,
) : TokenRefreshing {

  override suspend fun refresh(refreshToken: String): TokenPair = withContext(Dispatchers.IO) {
    val payload = json.encodeToString(RefreshRequest.serializer(), RefreshRequest(refreshToken))
    val request = Request.Builder()
      .url("$baseUrl/auth/refresh")
      .post(payload.toRequestBody(DeepJsonMediaType))
      .build()

    val response = try {
      client.newCall(request).execute()
    } catch (offline: IOException) {
      throw DeepApiException.Transport(offline.message ?: "Network error", offline)
    }

    response.use { raw ->
      val text = raw.body.string()
      if (!raw.isSuccessful) throw DeepApiException.of(raw.code, text)

      val tokens = try {
        json.decodeFromString(TokenResponse.serializer(), text)
      } catch (malformed: Exception) {
        throw DeepApiException.Decoding(
          malformed.message ?: "Unreadable token response",
          malformed,
        )
      }

      TokenPair(access = tokens.accessToken, refresh = tokens.refreshToken)
    }
  }
}

@Serializable
private data class RefreshRequest(val refreshToken: String)

/** `rotateSession`'s reply (`auth/sessions.ts`). `expiresIn` is unused for now. */
@Serializable
private data class TokenResponse(
  val accessToken: String,
  val refreshToken: String,
  val expiresIn: Int = 0,
)
