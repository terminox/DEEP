package io.appbeyond.freelance.deep.networking

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import io.appbeyond.freelance.deep.auth.TokenPair
import io.appbeyond.freelance.deep.auth.TokenStoring
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import java.io.IOException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Where this device's token pair lives: Preferences DataStore, with each value
 * encrypted under an AES-256/GCM key held in the AndroidKeyStore.
 *
 * The honest twin of `KeychainTokenStore.swift`. Android has no Keychain, and
 * the Jetpack answer to that — `androidx.security:security-crypto`, with
 * `EncryptedSharedPreferences` — is deprecated and unmaintained, with documented
 * keyset-corruption crashes and synchronous main-thread I/O. So the two halves it
 * bundled are assembled here instead, out of platform pieces that are not going
 * anywhere: DataStore for the storage, AndroidKeyStore for the key.
 *
 * What that buys is the same thing the Keychain buys on iOS. The key material
 * never leaves the TEE or StrongBox, so a stolen `datastore/deep.auth.preferences_pb`
 * — pulled off a rooted device, or out of a backup — is ciphertext without a key.
 *
 * What it deliberately does not do is require the device to be unlocked. iOS
 * chose `kSecAttrAccessibleAfterFirstUnlock` so background work keeps its
 * session on a locked phone; `setUnlockedDeviceRequired(true)` would be stricter
 * than that and would fail a refresh in the background. See [secretKey].
 */
class KeystoreTokenStore(context: Context) : TokenStoring {

  private val store: DataStore<Preferences> = context.applicationContext.authDataStore

  /**
   * The decrypted pair, held in memory after the first read.
   *
   * `BearerToken` asks for this on every single request, and a GCM decrypt per
   * request — through the TEE, no less — is real time spent on an OkHttp
   * dispatcher thread for a value that only changes when the session rotates.
   * Sound because this process is the only writer and there is exactly one
   * instance of this class, built in `AppDependencies`.
   */
  @Volatile
  private var cached: TokenPair? = null

  @Volatile
  private var hasRead: Boolean = false

  override suspend fun tokens(): TokenPair? {
    if (hasRead) return cached

    return withContext(Dispatchers.IO) {
      val stored = try {
        store.data.first()
      } catch (unreadable: IOException) {
        // A corrupt or unreadable file is a signed-out device, not a crash.
        emptyPreferences()
      }

      val access = stored[ACCESS_KEY]?.let(::decrypt)
      val refresh = stored[REFRESH_KEY]?.let(::decrypt)
      val pair = if (access != null && refresh != null) TokenPair(access, refresh) else null

      cached = pair
      hasRead = true
      pair
    }
  }

  override suspend fun save(tokens: TokenPair) {
    withContext(Dispatchers.IO) {
      // Encrypt before opening the transaction: each value gets its own random
      // IV from the provider, and a failure here leaves the stored pair intact
      // rather than half-written.
      val access = encrypt(tokens.access)
      val refresh = encrypt(tokens.refresh)

      // One transaction, so no crash can leave a new access token beside the
      // refresh token it replaced — a pair deep-api reads as reuse, and answers
      // by revoking the whole session.
      store.edit { mutable ->
        mutable[ACCESS_KEY] = access
        mutable[REFRESH_KEY] = refresh
      }

      cached = tokens
      hasRead = true
    }
  }

  override suspend fun clear() {
    withContext(Dispatchers.IO) {
      store.edit { it.clear() }
      cached = null
      hasRead = true
    }
  }

  /** Whether a session is stored. The twin of `APIClient.isAuthenticated`. */
  suspend fun isSignedIn(): Boolean = tokens() != null

  // MARK: - Crypto primitives

  /**
   * The app's one token-encryption key, created on first use and then reused.
   *
   * Neither `setUserAuthenticationRequired` nor `setUnlockedDeviceRequired` is
   * set, on purpose. Both would make the key unusable exactly when a background
   * refresh needs it, and iOS made the same call with
   * `kSecAttrAccessibleAfterFirstUnlock`. The key is still hardware-backed and
   * still non-exportable; what is not bought here is protection against someone
   * holding an unlocked, rooted phone, which a token in a Keychain does not buy
   * either.
   */
  private fun secretKey(): SecretKey {
    val keyStore = KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }
    val existing = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
    if (existing != null) return existing.secretKey

    val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEY_STORE)
    generator.init(
      KeyGenParameterSpec.Builder(
        KEY_ALIAS,
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
      )
        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
        .setKeySize(AES_KEY_BITS)
        .build()
    )
    return generator.generateKey()
  }

  /**
   * `[iv length][iv][ciphertext+tag]`, Base64'd for a string preference.
   *
   * The IV is written alongside rather than fixed: GCM is catastrophically
   * insecure if an IV is ever reused under the same key, so each call takes the
   * fresh one the provider generated.
   *
   * Throws rather than swallowing. A token that silently failed to save would
   * read as a signed-out app on the next launch, with nothing to explain it.
   */
  private fun encrypt(value: String): String {
    val cipher = Cipher.getInstance(TRANSFORMATION)
    cipher.init(Cipher.ENCRYPT_MODE, secretKey())

    val iv = cipher.iv
    val body = cipher.doFinal(value.toByteArray(Charsets.UTF_8))

    val packed = ByteArray(1 + iv.size + body.size)
    packed[0] = iv.size.toByte()
    System.arraycopy(iv, 0, packed, 1, iv.size)
    System.arraycopy(body, 0, packed, 1 + iv.size, body.size)

    return Base64.encodeToString(packed, Base64.NO_WRAP)
  }

  /**
   * The inverse, and null for anything that will not come back.
   *
   * Broad on purpose: a key the platform invalidated, a truncated file, a value
   * written by an older format. Every one of them means the same thing to the
   * app — there is no usable session — and none of them is worth a crash on
   * launch.
   */
  private fun decrypt(stored: String): String? =
    try {
      val packed = Base64.decode(stored, Base64.NO_WRAP)
      val ivSize = packed[0].toInt()
      val iv = packed.copyOfRange(1, 1 + ivSize)
      val body = packed.copyOfRange(1 + ivSize, packed.size)

      val cipher = Cipher.getInstance(TRANSFORMATION)
      cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
      String(cipher.doFinal(body), Charsets.UTF_8)
    } catch (unreadable: Exception) {
      null
    }

  private companion object {
    const val ANDROID_KEY_STORE = "AndroidKeyStore"
    const val KEY_ALIAS = "io.appbeyond.freelance.deep.auth"
    const val TRANSFORMATION = "AES/GCM/NoPadding"
    const val AES_KEY_BITS = 256
    const val GCM_TAG_BITS = 128

    val ACCESS_KEY = stringPreferencesKey("access")
    val REFRESH_KEY = stringPreferencesKey("refresh")
  }
}

/**
 * The one DataStore behind [KeystoreTokenStore].
 *
 * Top level because the delegate installs a process-wide singleton per file
 * name, and creating a second one for the same file throws.
 */
private val Context.authDataStore: DataStore<Preferences> by preferencesDataStore(
  name = "deep.auth"
)
