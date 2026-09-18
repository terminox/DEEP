package io.appbeyond.freelance.deep.auth

/**
 * The access/refresh pair one session is made of.
 *
 * Deliberately not `@Serializable`: this module has no serialization plugin, and
 * the wire shape is a separate type in `:app` that the transport maps into this
 * one. Keeping them apart is what stops a rename on the backend from reaching
 * the refresh logic — and what lets the logic below be tested with no JSON, no
 * Android and no server.
 */
data class TokenPair(
  val access: String,
  val refresh: String,
)

/**
 * Where a session's tokens live between launches.
 *
 * The Android twin of `KeychainTokenStore.swift`, with one difference that runs
 * all the way through this file: every member suspends. iOS gets away with a
 * synchronous store because Keychain calls are cheap and safe from any actor.
 * The Android conformer writes through Preferences DataStore and encrypts with
 * an AndroidKeyStore key — file I/O and AES work — so hiding it behind a
 * blocking accessor would put both on whatever thread happened to ask.
 */
interface TokenStoring {

  /** The stored pair, or null when nobody is signed in. */
  suspend fun tokens(): TokenPair?

  /**
   * Replaces the pair.
   *
   * Must be atomic. Half a pair — a new access token beside the refresh token it
   * replaced — is worse than no pair at all: deep-api reads a re-presented
   * refresh token as theft and revokes the whole session.
   */
  suspend fun save(tokens: TokenPair)

  /** Ends the session on this device. */
  suspend fun clear()
}
