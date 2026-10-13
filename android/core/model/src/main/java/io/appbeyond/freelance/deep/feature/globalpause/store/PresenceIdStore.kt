package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.shared.persistence.BlobStoring
import io.appbeyond.freelance.deep.shared.persistence.readOrNull
import io.appbeyond.freelance.deep.shared.persistence.writeQuietly
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.UUID

/**
 * One stable anonymous presence identity per install, so reopening the session
 * never double-counts a signed-out member (the server keys signed-in members by
 * user id instead). iOS keeps it in `UserDefaults` under `pause.presenceId`.
 *
 * Device state, not account state: it survives a log out, as iOS's does.
 */
class PresenceIdStore(private val blob: BlobStoring) {

  private val lock = Mutex()

  @Volatile
  private var cached: String? = null

  suspend fun id(): String {
    cached?.let { return it }
    return lock.withLock {
      cached ?: run {
        // The server takes 8–64 characters; anything else is minted afresh.
        val stored = blob.readOrNull()?.takeIf { it.length in 8..64 }
        (stored ?: UUID.randomUUID().toString().also { blob.writeQuietly(it) }).also { cached = it }
      }
    }
  }
}
