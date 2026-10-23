package io.appbeyond.freelance.deep.feature.onboarding.store

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import io.appbeyond.freelance.deep.auth.Account
import io.appbeyond.freelance.deep.networking.DeepJson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import java.io.IOException

/**
 * The signed-in member's identity, cached for an offline launch — the
 * non-secret twin of [io.appbeyond.freelance.deep.auth.TokenStoring]. Backs
 * [ApiAccountStore] only; nothing else should read or write this key.
 *
 * One JSON blob under one key, the same shape as `APIAccountStore`'s
 * `UserDefaults` cache on iOS. Deliberately its own tiny wire type rather than
 * reusing [io.appbeyond.freelance.deep.networking.UserDto] — this cache's
 * format must not drift just because the server adds a field to `/me`.
 */
class AccountCache(context: Context) {

  private val store: DataStore<Preferences> = context.applicationContext.accountCacheDataStore

  /** The cached account, or null when nothing was ever cached (or it failed to decode). */
  suspend fun read(): Account? = withContext(Dispatchers.IO) {
    val stored = try {
      store.data.first()
    } catch (unreadable: IOException) {
      // A corrupt or unreadable file reads as no cache, not a crash.
      emptyPreferences()
    }

    stored[ACCOUNT_KEY]
      ?.let { json ->
        runCatching { DeepJson.decodeFromString(CachedAccountDto.serializer(), json) }.getOrNull()
      }
      ?.let { dto -> Account(id = dto.id, email = dto.email, displayName = dto.displayName) }
  }

  suspend fun write(account: Account) {
    withContext(Dispatchers.IO) {
      val dto = CachedAccountDto(id = account.id, email = account.email, displayName = account.displayName)
      val json = DeepJson.encodeToString(CachedAccountDto.serializer(), dto)
      store.edit { it[ACCOUNT_KEY] = json }
    }
  }

  suspend fun clear() {
    withContext(Dispatchers.IO) {
      store.edit { it.remove(ACCOUNT_KEY) }
    }
  }

  private companion object {
    val ACCOUNT_KEY = stringPreferencesKey("account")
  }
}

/** The cache's own wire shape — see the class doc for why it isn't [io.appbeyond.freelance.deep.networking.UserDto]. */
@Serializable
private data class CachedAccountDto(
  val id: String,
  val email: String,
  val displayName: String,
)

private val Context.accountCacheDataStore: DataStore<Preferences> by preferencesDataStore(
  name = "deep.account"
)
