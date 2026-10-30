package io.appbeyond.freelance.deep.feature.deepsound.store

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundShelf
import io.appbeyond.freelance.deep.feature.deepsound.model.TrackLyrics
import io.appbeyond.freelance.deep.networking.SoundService
import io.appbeyond.freelance.deep.networking.apiCall
import io.appbeyond.freelance.deep.networking.toDomain
import io.appbeyond.freelance.deep.networking.toShelves

/**
 * [SoundLibrary] over deep-api. The Android twin of `APISoundContentRepository.swift`,
 * minus `pauseHome()` — see [SoundLibrary]'s doc for why. The DTO → domain
 * mapping itself lives in `SoundDtos.kt`, next to the wire shapes it reads.
 *
 * **The shelves belong to an account.** Since DEEP Premium, `/sound/home`
 * answers each caller differently: a member's shelves carry every audio URL,
 * a free listener's mark premium tracks locked and withhold theirs. So the
 * kept copy ([cachedShelves]) is keyed by the account it was fetched for and
 * served to no one else — a free member signing in after a premium one must
 * never open on the premium shelves, nor keep them when their own fetch
 * fails. A fetch that lands after the account changed is thrown away rather
 * than kept or returned.
 *
 * @param currentAccountId the signed-in account's id, or null when signed out.
 */
class ApiSoundLibrary(
  private val service: SoundService,
  private val currentAccountId: () -> String?,
) : SoundLibrary {

  /** Shelves and the account they were fetched for. */
  private data class Kept(val accountId: String?, val shelves: List<SoundShelf>)

  @Volatile private var kept: Kept? = null

  override val cachedShelves: List<SoundShelf>?
    get() = kept?.takeIf { it.accountId == currentAccountId() }?.shelves

  override suspend fun shelves(): List<SoundShelf> {
    val askedFor = currentAccountId()
    val shelves = apiCall { service.home() }.toShelves()
    // Signed out, in or across while the request was out: its locks (and
    // audio) are another account's. Dropped, and the copy kept for that
    // account goes too.
    if (currentAccountId() != askedFor) {
      kept = null
      throw StaleAccountException()
    }
    kept = Kept(askedFor, shelves)
    return shelves
  }

  /** A response fetched for an account that is no longer signed in. */
  private class StaleAccountException :
    IllegalStateException("The DEEP Sound shelves were fetched for another account.")

  /**
   * Authorized for the same reason as the shelves: the verdict is per
   * listener. Not kept — the detail screen that asked holds it.
   */
  override suspend fun collection(id: String): SoundCollection =
    apiCall { service.collection(id) }.collection.toDomain()

  override suspend fun lyrics(trackId: String): List<TrackLyrics> =
    apiCall { service.lyrics(trackId) }.toDomain()
}
