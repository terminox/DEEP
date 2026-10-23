package io.appbeyond.freelance.deep.feature.playlist.store

import android.util.Log
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTrack
import io.appbeyond.freelance.deep.feature.playlist.model.PlaylistSnapshot
import io.appbeyond.freelance.deep.feature.playlist.model.SavedSound
import io.appbeyond.freelance.deep.networking.DeepApiException
import io.appbeyond.freelance.deep.networking.PlaylistDto
import io.appbeyond.freelance.deep.networking.PlaylistItemRequest
import io.appbeyond.freelance.deep.networking.SoundService
import io.appbeyond.freelance.deep.networking.apiCall
import io.appbeyond.freelance.deep.networking.toDomain
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.util.concurrent.atomic.AtomicLong

/**
 * [PlaylistStore] backed by the DEEP backend. The Android twin of
 * `PlaylistStore.swift`, folding what iOS splits into `PlaylistStore` +
 * `PlaylistRemote` into one class — [SoundService] and [cache] play the part
 * `APIPlaylistRemote` and its `UserDefaults` blob play there, the same
 * shape `ApiAccountStore` already gives `AuthService` + `AccountCache`.
 *
 * [PlaylistSnapshot]'s pure functions own the optimistic ordering rules
 * (insert at the top, restore to the removed slot on a refused removal); this
 * class owns the coroutines, the network and the cache around them.
 *
 * Every round trip — a [load], a save/remove inside [toggle], and the
 * cold-launch cache hydration below — runs on [scope] rather than the
 * calling screen's, via [runMutation], and the caller only awaits it. A
 * screen closing mid-toggle (`NowPlayingScreen`, `CollectionDetailScreen`
 * and `PlaylistScreen` all fire [toggle] on their own composable scope) then
 * just stops waiting; it can't cancel the network call or skip past its
 * reconcile/rollback the way a plain `try`/catch on [DeepApiException] alone
 * would let it. Those same round trips are serialized by [mutex] and stamped
 * with [generation], bumped at the start of every mutation and by
 * [resetLocalState]: a response (or the cached snapshot below) is only
 * applied, and only written to [cache], if [generation] hasn't moved since —
 * otherwise a newer toggle, load or a sign-out has superseded it, and
 * applying it anyway is exactly how the previous listener's playlist used to
 * resurface after sign-out or a member switch. The optimistic edit inside
 * [save]/[remove] is the one thing applied outside the lock, so [state]
 * still moves the instant a listener taps a bookmark.
 *
 * @param scope A process-lifetime scope (`AppDependencies`' `appScope`, not a
 *   screen's) every mutation actually runs on — see above. Also used to
 *   hydrate [state] from [cache] in the background so an offline cold launch
 *   has something to show before the first [load] lands, mirroring iOS
 *   reading its `UserDefaults` blob synchronously in `init`.
 */
class ApiPlaylistStore(
  private val service: SoundService,
  private val cache: PlaylistCache,
  private val scope: CoroutineScope,
) : PlaylistStore {

  private val _state = MutableStateFlow<PlaylistState>(PlaylistState.Loading)
  override val state: StateFlow<PlaylistState> = _state.asStateFlow()

  /** Serializes every [load]/[toggle] round trip against each other — see the class doc. */
  private val mutex = Mutex()

  /**
   * Bumped by [runMutation] as each mutation actually starts (after [mutex] is acquired) and by
   * [resetLocalState] immediately, without waiting on [mutex]. [isCurrent] is how a mutation asks
   * "is my response still the latest thing that was asked for" before applying it or writing
   * [cache] — the reset bump is what lets a sign-out invalidate a mutation that's already holding
   * the lock, rather than queueing behind it and resurrecting stale state once it finally runs.
   */
  private val generation = AtomicLong(0)

  /** The default playlist's id — needed by every save/remove call. Null until the first [load] or cache hit. */
  @Volatile private var playlistId: String? = null

  /** The book-keeping half of [state]: what [PlaylistSnapshot] edits, [state] is derived from. */
  @Volatile private var sounds: List<SavedSound> = emptyList()

  init {
    scope.launch {
      val cached = cache.read() ?: return@launch
      mutex.withLock {
        if (_state.value is PlaylistState.Loading) {
          adopt(cached, generation.incrementAndGet())
        }
      }
    }
  }

  override fun isSaved(trackId: String): Boolean = PlaylistSnapshot.isSaved(sounds, trackId)

  override suspend fun load() {
    runMutation { myGeneration ->
      try {
        val playlists = apiCall { service.playlists() }.playlists
        val default = playlists.firstOrNull { it.isDefault } ?: playlists.firstOrNull()
        if (default == null) {
          if (isCurrent(myGeneration)) {
            playlistId = null
            sounds = emptyList()
            _state.value = PlaylistState.Loaded(emptyList())
          }
          return@runMutation
        }
        adopt(default, myGeneration)
      } catch (api: DeepApiException) {
        // A cached or previously-loaded snapshot on screen is worth more than an
        // error; only a first load with nothing to show surfaces the failure.
        if (isCurrent(myGeneration) && _state.value !is PlaylistState.Loaded) {
          _state.value = PlaylistState.Failed(api)
        }
      }
    }
  }

  override suspend fun toggle(track: SoundTrack, collection: SoundCollection) {
    // A save needs the default playlist's id, and a fresh install with no
    // cache only learns it from a load — which, left to the You tab, never
    // ran for someone saving from a collection first, and the save was
    // dropped without a word. Fetch it now instead; a load that fails leaves
    // the id null and the toggle a no-op, as before.
    if (playlistId == null) load()
    if (PlaylistSnapshot.isSaved(sounds, track.id)) {
      remove(track)
    } else {
      save(track, collection)
    }
  }

  override suspend fun resetLocalState() {
    // Bumped and applied immediately — before touching mutex — so a load/toggle already holding
    // it can't land a stale response or cache write once it finally runs; see isCurrent.
    generation.incrementAndGet()
    playlistId = null
    sounds = emptyList()
    _state.value = PlaylistState.Loading
    scope.launch {
      mutex.withLock {
        bestEffort("clear the cached playlist") { cache.clear() }
      }
    }.join()
  }

  // MARK: - Saving

  private suspend fun save(track: SoundTrack, collection: SoundCollection) {
    val list = playlistId ?: return
    if (PlaylistSnapshot.isSaved(sounds, track.id)) return

    val placeholder = SavedSound(
      // A placeholder id until the server's lands with the reconcile — it only
      // has to be unique within the list for the round trip's duration.
      itemId = "pending-${track.id}",
      savedAt = Instant.now(),
      entry = SoundQueueEntry(track, collection),
    )
    applyLocally(PlaylistSnapshot.insert(sounds, placeholder))

    runMutation { myGeneration ->
      try {
        val settled = apiCall { service.saveItem(list, PlaylistItemRequest(trackId = track.id)) }.playlist
        adopt(settled, myGeneration)
      } catch (failed: DeepApiException) {
        if (isCurrent(myGeneration)) applyLocally(PlaylistSnapshot.remove(sounds, track.id))
      }
    }
  }

  // MARK: - Removing

  private suspend fun remove(track: SoundTrack) {
    val list = playlistId ?: return
    val removed = sounds.firstOrNull { it.entry.track.id == track.id } ?: return
    applyLocally(PlaylistSnapshot.remove(sounds, track.id))

    runMutation { myGeneration ->
      try {
        val settled = apiCall { service.removeItem(list, track.id) }.playlist
        adopt(settled, myGeneration)
      } catch (failed: DeepApiException) {
        // Puts the removed sound back where it was, so a refused round trip doesn't
        // quietly reorder the list — unless something newer has already superseded it.
        if (isCurrent(myGeneration)) applyLocally(PlaylistSnapshot.restore(sounds, removed))
      }
    }
  }

  // MARK: - Book-keeping

  /**
   * Runs [block] on [scope] — never the caller's coroutine — and serializes it against every
   * other mutation via [mutex], so a caller cancelling its own scope only stops awaiting; it
   * can't cancel [block] or interleave its response with another mutation's. [block] receives the
   * generation stamped the moment it actually starts (after [mutex] is acquired), for [isCurrent].
   *
   * An exception [block] doesn't already handle itself (every call site only expects
   * [DeepApiException]) is logged and swallowed here rather than left to propagate: [scope] is
   * shared and process-lifetime, so an uncaught failure in one mutation must not cancel it and
   * take every future load/toggle down with it.
   */
  private suspend fun runMutation(block: suspend (myGeneration: Long) -> Unit) {
    scope.launch {
      mutex.withLock {
        val myGeneration = generation.incrementAndGet()
        try {
          block(myGeneration)
        } catch (cancelled: CancellationException) {
          throw cancelled
        } catch (unexpected: Exception) {
          Log.w(TAG, "Unexpected failure applying a playlist mutation.", unexpected)
        }
      }
    }.join()
  }

  /** Whether [myGeneration] is still the latest — see [generation]'s doc. */
  private fun isCurrent(myGeneration: Long): Boolean = myGeneration == generation.get()

  /**
   * Adopts the server's version of the default playlist — normally identical to the optimistic
   * one. Applied, and cached, only while [myGeneration] is still current: a reset or a newer
   * mutation that started since would mean this response is stale, so it's dropped rather than
   * clobbering fresher state or writing it to [cache].
   */
  private suspend fun adopt(dto: PlaylistDto, myGeneration: Long) {
    if (!isCurrent(myGeneration)) return
    playlistId = dto.id
    applyLocally(dto.toSavedSounds())
    bestEffort("cache the playlist") { cache.write(dto) }
  }

  /** The optimistic half of a save/remove — applied instantly, outside [mutex], so [state] moves without waiting on the network. */
  private fun applyLocally(next: List<SavedSound>) {
    sounds = next
    _state.value = PlaylistState.Loaded(next.map { it.entry })
  }

  /**
   * The cache is a convenience for an offline cold launch, never a reason to
   * fail a load, a save or a removal: a DataStore I/O error is logged and
   * dropped, mirroring [io.appbeyond.freelance.deep.feature.onboarding.store.ApiAccountStore.bestEffort].
   */
  private suspend fun bestEffort(what: String, block: suspend () -> Unit) {
    try {
      block()
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (failure: Exception) {
      Log.w(TAG, "Could not $what.", failure)
    }
  }

  private companion object {
    const val TAG = "ApiPlaylistStore"
  }
}

/** `serializePlaylistItem`'s shape, mapped down to the [SavedSound]s [PlaylistSnapshot] edits. */
private fun PlaylistDto.toSavedSounds(): List<SavedSound> =
  (items ?: emptyList()).map { item ->
    SavedSound(
      itemId = item.id,
      savedAt = item.savedAt,
      entry = SoundQueueEntry(track = item.track.toDomain(), collection = item.collection.toDomain()),
    )
  }
