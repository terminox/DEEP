package io.appbeyond.freelance.deep.shared.persistence

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStoreFile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import java.io.IOException

/**
 * [BlobStoring] over one Preferences DataStore file — the shipped conformer
 * behind every `:core:model` store that persists its whole state as a single
 * JSON blob (`GardenStore`, `PracticeJournal`, `ContinuityWitness`). The
 * Android twin of those stores' `UserDefaults` keys on iOS.
 *
 * One class, one instance per file: `AppDependencies` builds one for
 * `deep.garden`, one for `deep.practice` and one for `deep.continuity`. A file
 * per store rather than keys in a shared file, so one store's rewrite never
 * rewrites (or corrupts) another's, and a reset is just this file's key gone.
 * Shaped like `PlaylistCache` and `DataStoreOnboardingProgressStore`: I/O on
 * [Dispatchers.IO], and an unreadable file reads as empty rather than crashing
 * a cold launch.
 *
 * DataStore refuses two live instances over the same file in one process, so
 * the underlying [DataStore] is shared per [fileName] — constructing this twice
 * for one name is harmless rather than a crash on first read.
 *
 * @param fileName the DataStore file, e.g. `deep.garden`.
 */
class DataStoreBlobStore(context: Context, fileName: String) : BlobStoring {

  private val store: DataStore<Preferences> = dataStoreFor(context.applicationContext, fileName)

  override suspend fun read(): String? = withContext(Dispatchers.IO) {
    val stored = try {
      store.data.first()
    } catch (unreadable: IOException) {
      emptyPreferences()
    }
    stored[BLOB_KEY]
  }

  /** Replaces the blob; null removes the key, so a reset leaves nothing behind. */
  override suspend fun write(value: String?) {
    withContext(Dispatchers.IO) {
      store.edit { preferences ->
        if (value == null) preferences.remove(BLOB_KEY) else preferences[BLOB_KEY] = value
      }
    }
  }

  private companion object {
    val BLOB_KEY = stringPreferencesKey("blob")

    /** Every DataStore this process has opened, by file name. */
    private val stores = HashMap<String, DataStore<Preferences>>()

    fun dataStoreFor(context: Context, fileName: String): DataStore<Preferences> =
      synchronized(stores) {
        stores.getOrPut(fileName) {
          PreferenceDataStoreFactory.create { context.preferencesDataStoreFile(fileName) }
        }
      }
  }
}
