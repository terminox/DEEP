package io.appbeyond.freelance.deep.feature.playlist.store

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTrack
import io.appbeyond.freelance.deep.networking.DeepApiException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * In-memory [PlaylistStore] for previews — no networking, no persistence,
 * [toggle] applied straight to [state]. The Android twin of the fixture
 * extension iOS hangs off `PlaylistStore` itself (`.sample`, `.empty`,
 * `.loading`, `.failed`).
 */
class MockPlaylistStore(initial: PlaylistState = PlaylistState.Loading) : PlaylistStore {

  private val _state = MutableStateFlow(initial)
  override val state: StateFlow<PlaylistState> = _state.asStateFlow()

  override fun isSaved(trackId: String): Boolean =
    (_state.value as? PlaylistState.Loaded)?.entries?.any { it.track.id == trackId } == true

  override suspend fun load() {
    // A fixture never has anything new to fetch; whatever it was constructed
    // with stands. `.failing` covers the retry state without a real load.
  }

  override suspend fun toggle(track: SoundTrack, collection: SoundCollection) {
    val entries = (_state.value as? PlaylistState.Loaded)?.entries ?: return
    _state.value = PlaylistState.Loaded(
      if (entries.any { it.track.id == track.id }) {
        entries.filterNot { it.track.id == track.id }
      } else {
        listOf(SoundQueueEntry(track, collection)) + entries
      },
    )
  }

  override suspend fun resetLocalState() {
    _state.value = PlaylistState.Loading
  }

  companion object {
    /** A playlist with sounds in it, for previews of the loaded state. */
    val sample: MockPlaylistStore get() = MockPlaylistStore(PlaylistState.Loaded(PlaylistFixtures.saved))

    /** Nothing saved yet — the invitation state. */
    val empty: MockPlaylistStore get() = MockPlaylistStore(PlaylistState.Loaded(emptyList()))

    /** Still fetching — the breathing skeleton. */
    val loading: MockPlaylistStore get() = MockPlaylistStore(PlaylistState.Loading)

    /** Nothing cached and the fetch refused — the retry state. */
    val failed: MockPlaylistStore
      get() = MockPlaylistStore(PlaylistState.Failed(DeepApiException.Transport("Mock failure")))
  }
}
