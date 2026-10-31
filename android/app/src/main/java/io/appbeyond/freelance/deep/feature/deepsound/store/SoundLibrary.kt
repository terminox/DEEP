package io.appbeyond.freelance.deep.feature.deepsound.store

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundShelf
import io.appbeyond.freelance.deep.feature.deepsound.model.TrackLyrics
import io.appbeyond.freelance.deep.feature.premium.model.KeptContent

/**
 * The content seam for DEEP Sound. Ported from `SoundContentRepository.swift`,
 * narrowed to what this port needs so far — the home shelves and a track's
 * lyrics; `pauseHome()` stays on [io.appbeyond.freelance.deep.networking.PauseHomeRepository],
 * which already ships its own `/pause/home` seam.
 *
 * The home screen reads [shelves]; the Now Playing screen reads [lyrics].
 * Screens depend on this interface so they preview against [MockSoundLibrary]
 * rather than the network — the `AccountStore` / `OnboardingRemote` pattern.
 *
 * Every suspend member throws [io.appbeyond.freelance.deep.networking.DeepApiException]
 * on failure; callers show a failed state rather than catching a checked error.
 * Conformers: [ApiSoundLibrary], [MockSoundLibrary].
 */
interface SoundLibrary {

  /**
   * `GET /sound/home` (optional auth) — every category as a shelf, collections
   * and tracks in server order, DEEP Premium content marked locked (and without
   * audio) for a caller who is not a member.
   */
  suspend fun shelves(): List<SoundShelf>

  /**
   * The shelves the last successful [shelves] returned this run, or null.
   * The home screen opens on these when it is rebuilt — coming back from a
   * collection, or from another tab — instead of a skeleton, so its scroll
   * position has rows to land on. iOS never needs it: its home view stays
   * alive under the pushed screen.
   */
  val cachedShelves: List<SoundShelf>? get() = null

  /**
   * `GET /sound/collections/{id}` (optional auth) — one collection, fresh,
   * for a detail screen whose copy was fetched before the listener's DEEP
   * Premium answer changed: the verdicts (and the withheld audio) it carries
   * are the asker's.
   */
  suspend fun collection(id: String): SoundCollection

  /**
   * The freshest copy of a collection kept for the signed-in account — from
   * an earlier [collection] or riding the kept [shelves] — stamped with the
   * DEEP Premium content epoch it was fetched under. Null when nothing is
   * kept for it.
   */
  fun keptCollection(id: String): KeptContent<SoundCollection>? = null

  /**
   * Fetches again everything kept for the signed-in account, so content
   * carrying an older premium answer's verdicts is replaced even while no
   * screen is showing it. Never throws.
   */
  suspend fun refreshKept() {}

  /** `GET /sound/tracks/{id}/lyrics` (anon) — every language for the track; empty when it has none. */
  suspend fun lyrics(trackId: String): List<TrackLyrics>
}
