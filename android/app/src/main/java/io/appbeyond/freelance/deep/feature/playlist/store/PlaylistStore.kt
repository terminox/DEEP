package io.appbeyond.freelance.deep.feature.playlist.store

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTrack
import io.appbeyond.freelance.deep.networking.DeepApiException
import kotlinx.coroutines.flow.StateFlow

/**
 * The saved sounds, shared by every screen that can save one. Ported from
 * `PlaylistStore.swift`, reshaped to this codebase's contract-plus-conformers
 * pattern ([AccountStore][io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore])
 * rather than the single `@Observable` class iOS uses — a `MockPlaylistStore`
 * conforms with no backend at all, the same way `MockAccountStore` does.
 *
 * A bookmark reads [isSaved]; a save/remove control calls [toggle]. Every
 * screen that can show a save is reading the same [state], so saving a sound
 * anywhere fills the mark everywhere at once. Conformers: [ApiPlaylistStore],
 * [MockPlaylistStore].
 */
interface PlaylistStore {

  /**
   * Starts at [PlaylistState.Loading] until the first [load]. Entries are the
   * listener's default playlist, most recently saved first — the same
   * "newest first" [state] carries on iOS, just flattened to the one list a
   * single playlist needs; see [PlaylistState.Loaded].
   */
  val state: StateFlow<PlaylistState>

  /** Track ids currently saved — what every bookmark glyph reads, without a scan of [state]. */
  fun isSaved(trackId: String): Boolean

  /**
   * `GET /me/playlists`. A refresh that finds [state] already [PlaylistState.Loaded]
   * and fails leaves it exactly as it was — a cached snapshot on screen is
   * worth more than an error; only a first load with nothing cached lands on
   * [PlaylistState.Failed]. Mirrors `PlaylistStore.refresh()`.
   */
  suspend fun load()

  /**
   * Saves [track] if it isn't already saved, or takes it out if it is.
   * Optimistic: [state] moves before the round trip starts, then either
   * reconciles against the server's playlist or rolls back on failure.
   * Mirrors `PlaylistStore.toggle(_:from:)`.
   */
  suspend fun toggle(track: SoundTrack, collection: SoundCollection)

  /**
   * Forgets the signed-out account's playlist, on screen and (for
   * [ApiPlaylistStore]) on disk, so the next listener's first load never
   * shows a previous one's saved sounds while it is in flight. Mirrors
   * `PlaylistStore.resetLocalState()`; called the same way Settings calls it
   * on iOS — after a voluntary log out or account deletion, and from
   * `AppDependencies`' `onInvoluntarySignOut` when the server ends the
   * session instead.
   */
  suspend fun resetLocalState()
}

/** [PlaylistStore.state] — loading / loaded / failed, nothing more. */
sealed interface PlaylistState {

  /** Nothing fetched yet this run. */
  data object Loading : PlaylistState

  /** [entries] newest-saved-first — see [SoundQueueEntry]. */
  data class Loaded(val entries: List<SoundQueueEntry>) : PlaylistState

  /** Nothing cached and the fetch was refused — the retry state. */
  data class Failed(val error: DeepApiException) : PlaylistState
}
