package io.appbeyond.freelance.deep.feature.playlist.store

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import io.appbeyond.freelance.deep.networking.DeepJson
import io.appbeyond.freelance.deep.networking.PlaylistDto
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import java.io.IOException

/**
 * The listener's default playlist, cached as one JSON blob so an offline cold
 * launch opens on the saved sounds instead of an empty state — the Android
 * twin of `PlaylistStore`'s `UserDefaults` snapshot (see that class's doc on
 * iOS). Backs [ApiPlaylistStore] only, the same relationship
 * [io.appbeyond.freelance.deep.feature.onboarding.store.AccountCache] has to
 * `ApiAccountStore`.
 *
 * Caches the raw [PlaylistDto] rather than a store-shaped snapshot, so the
 * same `PlaylistDto.toSavedSounds()` mapping in `ApiPlaylistStore.kt` reads a
 * cold launch and a live fetch alike.
 */
class PlaylistCache(context: Context) {

  private val store: DataStore<Preferences> = context.applicationContext.playlistCacheDataStore

  /** The cached playlist, or null when nothing was ever cached (or it failed to decode). */
  suspend fun read(): PlaylistDto? = withContext(Dispatchers.IO) {
    val stored = try {
      store.data.first()
    } catch (unreadable: IOException) {
      // A corrupt or unreadable file reads as no cache, not a crash.
      emptyPreferences()
    }

    stored[SNAPSHOT_KEY]?.let { json ->
      runCatching { DeepJson.decodeFromString(PlaylistDto.serializer(), json) }.getOrNull()
    }
  }

  suspend fun write(playlist: PlaylistDto) {
    withContext(Dispatchers.IO) {
      val json = DeepJson.encodeToString(PlaylistDto.serializer(), playlist)
      store.edit { it[SNAPSHOT_KEY] = json }
    }
  }

  suspend fun clear() {
    withContext(Dispatchers.IO) {
      store.edit { it.remove(SNAPSHOT_KEY) }
    }
  }

  private companion object {
    val SNAPSHOT_KEY = stringPreferencesKey("snapshot")
  }
}

private val Context.playlistCacheDataStore: DataStore<Preferences> by preferencesDataStore(
  name = "deep.playlist"
)
