package io.appbeyond.freelance.deep.feature.deepsound.store

import android.util.Log
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundShelf
import io.appbeyond.freelance.deep.feature.deepsound.model.TrackLyrics
import io.appbeyond.freelance.deep.feature.premium.model.KeptContent
import io.appbeyond.freelance.deep.networking.SoundService
import io.appbeyond.freelance.deep.networking.apiCall
import io.appbeyond.freelance.deep.networking.toDomain
import io.appbeyond.freelance.deep.networking.toShelves
import kotlinx.coroutines.CancellationException
import java.util.concurrent.ConcurrentHashMap

/**
 * [SoundLibrary] over deep-api. The Android twin of `APISoundContentRepository.swift`,
 * minus `pauseHome()` — see [SoundLibrary]'s doc for why. The DTO → domain
 * mapping itself lives in `SoundDtos.kt`, next to the wire shapes it reads.
 *
 * **What it keeps belongs to an account.** Since DEEP Premium, `/sound/home`
 * and `/sound/collections/{id}` answer each caller differently: a member's
 * copy carries every audio URL, a free listener's marks premium tracks locked
 * and withholds theirs. So every kept copy ([cachedShelves],
 * [keptCollection]) is stamped with the account it was fetched for and
 * served to no one else — a free member signing in after a premium one must
 * never open on the premium shelves, nor keep them when their own fetch
 * fails. A fetch that lands after the account changed is thrown away rather
 * than kept or returned.
 *
 * **…and to a premium answer.** Each copy is also stamped with the DEEP
 * Premium content epoch it was fetched under ([KeptContent]), so a screen
 * rebuilt after the answer moved can tell a stale copy from a fresh one, and
 * [refreshKept] — run app-wide whenever the epoch moves — re-fetches what is
 * kept whether or not any screen is showing it.
 *
 * @param currentAccountId the signed-in account's id, or null when signed out.
 * @param currentEpoch the DEEP Premium content epoch right now.
 */
class ApiSoundLibrary(
  private val service: SoundService,
  private val currentAccountId: () -> String?,
  private val currentEpoch: () -> Int = { 0 },
) : SoundLibrary {

  @Volatile private var kept: KeptContent<List<SoundShelf>>? = null

  /** Collections fetched one at a time (a detail screen's refresh), by id. */
  private val keptCollections = ConcurrentHashMap<String, KeptContent<SoundCollection>>()

  override val cachedShelves: List<SoundShelf>?
    get() = kept?.takeIf { it.owner == currentAccountId() }?.value

  override suspend fun shelves(): List<SoundShelf> {
    val askedFor = currentAccountId()
    // The epoch as the request leaves: an answer that moves while it is out
    // finds this copy stale.
    val epoch = currentEpoch()
    val shelves = apiCall { service.home() }.toShelves()
    // Signed out, in or across while the request was out: its locks (and
    // audio) are another account's. Dropped, and the copy kept for that
    // account goes too.
    if (currentAccountId() != askedFor) {
      kept = null
      keptCollections.clear()
      throw StaleAccountException()
    }
    kept = KeptContent(askedFor, epoch, shelves)
    return shelves
  }

  /** A response fetched for an account that is no longer signed in. */
  private class StaleAccountException :
    IllegalStateException("DEEP Sound content was fetched for another account.")

  /**
   * Authorized for the same reason as the shelves: the verdict is per
   * listener. Kept, stamped, so a detail screen rebuilt later opens on it.
   */
  override suspend fun collection(id: String): SoundCollection {
    val askedFor = currentAccountId()
    val epoch = currentEpoch()
    val collection = apiCall { service.collection(id) }.collection.toDomain()
    if (currentAccountId() != askedFor) {
      keptCollections.clear()
      throw StaleAccountException()
    }
    keep(id, KeptContent(askedFor, epoch, collection))
    return collection
  }

  /** Keeps [copy] unless a copy fetched under a newer epoch is already there. */
  private fun keep(id: String, copy: KeptContent<SoundCollection>) {
    keptCollections.merge(id, copy) { old, new -> if (new.epoch >= old.epoch) new else old }
  }

  /**
   * The freshest copy of a collection kept for the signed-in account: fetched
   * on its own, or riding the kept shelves (`/sound/home` sends every
   * collection with its tracks).
   */
  override fun keptCollection(id: String): KeptContent<SoundCollection>? {
    val owner = currentAccountId()
    val own = keptCollections[id]?.takeIf { it.owner == owner }
    val onShelf = kept?.takeIf { it.owner == owner }?.let { shelves ->
      shelves.value.asSequence()
        .flatMap { it.collections.asSequence() }
        .firstOrNull { it.id == id }
        ?.let { KeptContent(shelves.owner, shelves.epoch, it) }
    }
    return KeptContent.freshest(own, onShelf)
  }

  override suspend fun refreshKept() {
    val owner = currentAccountId()
    if (kept?.owner == owner && kept != null) quietly("re-fetch the shelves") { shelves() }
    keptCollections.filterValues { it.owner == owner }.keys.forEach { id ->
      quietly("re-fetch a kept collection") { collection(id) }
    }
  }

  override suspend fun lyrics(trackId: String): List<TrackLyrics> =
    apiCall { service.lyrics(trackId) }.toDomain()

  /** A failed re-fetch keeps the copy it would have replaced; the screens retry on their own. */
  private suspend fun quietly(what: String, block: suspend () -> Unit) {
    try {
      block()
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (failure: Exception) {
      Log.w(TAG, "Could not $what.", failure)
    }
  }

  private companion object {
    const val TAG = "ApiSoundLibrary"
  }
}
