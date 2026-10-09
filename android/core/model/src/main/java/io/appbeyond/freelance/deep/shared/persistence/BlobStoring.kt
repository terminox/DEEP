package io.appbeyond.freelance.deep.shared.persistence

import kotlinx.coroutines.CancellationException

/**
 * One text blob that survives a relaunch — the seam behind every store that
 * persists its whole state under a single key.
 *
 * The Android twin of the iOS stores' `UserDefaults` JSON-blob pattern
 * (`GardenStore`, `PracticeDefaultsStore`, `ContinuityWitness`): each store owns
 * one instance, re-encodes its entire state on every mutation, and decodes it
 * back on first use. Each member suspends because the shipped conformer writes
 * through Preferences DataStore — file I/O that must not run on whatever thread
 * happened to ask (the [io.appbeyond.freelance.deep.auth.TokenStoring]
 * reasoning).
 */
interface BlobStoring {

  /** The stored blob, or null when nothing was ever written (or it was cleared). */
  suspend fun read(): String?

  /** Replaces the blob; null removes it. */
  suspend fun write(value: String?)
}

/**
 * A blob held in memory only — tests, Compose previews, and anywhere a store
 * should start empty every launch.
 */
class InMemoryBlobStore(initial: String? = null) : BlobStoring {

  @Volatile
  var value: String? = initial
    private set

  /** How many writes have landed — lets a test assert that a mutation persisted. */
  @Volatile
  var writes: Int = 0
    private set

  override suspend fun read(): String? = value

  override suspend fun write(value: String?) {
    this.value = value
    writes++
  }
}

/** Reads a blob, treating an unreadable store as an empty one — never a crash. */
internal suspend fun BlobStoring.readOrNull(): String? = try {
  read()
} catch (cancelled: CancellationException) {
  throw cancelled
} catch (_: Exception) {
  null
}

/**
 * Writes a blob, swallowing a failed write: the in-memory state already moved
 * and stays authoritative for this launch (the iOS `try?` on every persist).
 */
internal suspend fun BlobStoring.writeQuietly(value: String?) {
  try {
    write(value)
  } catch (cancelled: CancellationException) {
    throw cancelled
  } catch (_: Exception) {
    // Nothing to do — the next mutation re-encodes the whole state anyway.
  }
}
