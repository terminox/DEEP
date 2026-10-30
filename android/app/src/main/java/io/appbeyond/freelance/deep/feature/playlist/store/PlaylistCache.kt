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
import kotlinx.serialization.Serializable
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
 *
 * **It belongs to one member.** Since DEEP Premium the server's playlist
 * carries per-listener verdicts and, for a member, premium audio URLs — so
 * the snapshot is stamped with the DEEP user id it was fetched for and read
 * back only for that same id. A snapshot without an owner (written before
 * the stamp existed) is never handed to anyone. Even read by its owner after
 * a lapse it can never unlock anything: every lock goes through `PremiumGate`,
 * where a kept `isLocked: false` adds nothing and `isPremium` still locks.
 */
class PlaylistCache(context: Context) {

  private val store: DataStore<Preferences> = context.applicationContext.playlistCacheDataStore

  /** The playlist cached for [owner], or null when there is none for them (or it failed to decode). */
  suspend fun read(owner: String): PlaylistDto? = withContext(Dispatchers.IO) {
    val stored = try {
      store.data.first()
    } catch (unreadable: IOException) {
      // A corrupt or unreadable file reads as no cache, not a crash.
      emptyPreferences()
    }

    stored[OWNED_SNAPSHOT_KEY]
      ?.let { json -> runCatching { DeepJson.decodeFromString(OwnedPlaylist.serializer(), json) }.getOrNull() }
      ?.takeIf { it.owner == owner }
      ?.playlist
  }

  suspend fun write(owner: String, playlist: PlaylistDto) {
    withContext(Dispatchers.IO) {
      val json = DeepJson.encodeToString(OwnedPlaylist.serializer(), OwnedPlaylist(owner, playlist))
      store.edit {
        it[OWNED_SNAPSHOT_KEY] = json
        it.remove(LEGACY_SNAPSHOT_KEY)
      }
    }
  }

  suspend fun clear() {
    withContext(Dispatchers.IO) {
      store.edit {
        it.remove(OWNED_SNAPSHOT_KEY)
        it.remove(LEGACY_SNAPSHOT_KEY)
      }
    }
  }

  private companion object {
    val OWNED_SNAPSHOT_KEY = stringPreferencesKey("owned-snapshot")

    /** The ownerless snapshot builds before DEEP Premium wrote: never read, removed on the next write. */
    val LEGACY_SNAPSHOT_KEY = stringPreferencesKey("snapshot")
  }
}

/** The cache's shape: the playlist and the DEEP user id it was fetched for. */
@Serializable
private data class OwnedPlaylist(
  val owner: String,
  val playlist: PlaylistDto,
)

private val Context.playlistCacheDataStore: DataStore<Preferences> by preferencesDataStore(
  name = "deep.playlist"
)
