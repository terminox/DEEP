package io.appbeyond.freelance.deep.feature.playlist.model

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import java.time.Instant

/**
 * One sound saved to the listener's playlist, together with the bookkeeping a
 * reconcile needs. Ported from `PlaylistEntry` (Deep/Deep/Features/Playlist/Models/Playlist.swift),
 * folded down to what [SoundQueueEntry] does not already carry: the playlist
 * item's own id (server-assigned, or a `pending-<trackId>` placeholder while a
 * save is in flight) and when it was saved, which is what orders the list and
 * gives a rolled-back removal its slot back.
 */
data class SavedSound(
  val itemId: String,
  val savedAt: Instant,
  val entry: SoundQueueEntry,
)

/**
 * The pure edits `PlaylistStore`'s optimistic toggle is built from — no
 * coroutines, no network, no Android. A straight port of the private
 * `insertEntry`/`removeEntry`/`rollbackRemove` book-keeping in
 * `PlaylistStore.swift`, kept in `:core:model` so the ordering rules (newest
 * first; a rolled-back removal returns to its own slot rather than jumping to
 * the top) are covered by a fast JUnit test, the same reasoning as
 * [io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueue] and
 * `PracticeMath`.
 */
object PlaylistSnapshot {

  /** Whether [trackId] is already saved — what every bookmark glyph reads. */
  fun isSaved(sounds: List<SavedSound>, trackId: String): Boolean =
    sounds.any { it.entry.track.id == trackId }

  /**
   * Optimistic save: [saved] appears at the top immediately, before its round
   * trip has even started. A no-op if the track is already there — saving
   * something twice changes nothing, mirroring `PlaylistStore.save`'s own
   * `!isSaved(track)` guard.
   */
  fun insert(sounds: List<SavedSound>, saved: SavedSound): List<SavedSound> =
    if (isSaved(sounds, saved.entry.track.id)) sounds else listOf(saved) + sounds

  /**
   * Optimistic removal, and also a refused save's rollback — both just drop
   * the track. A no-op if it isn't there.
   */
  fun remove(sounds: List<SavedSound>, trackId: String): List<SavedSound> =
    sounds.filterNot { it.entry.track.id == trackId }

  /**
   * A refused removal's rollback: puts [removed] back where it was rather
   * than at the top, so a failed round trip doesn't quietly reorder the list.
   * Mirrors `PlaylistStore.rollbackRemove(of:in:)` — inserted just before the
   * first sound saved earlier than it, or appended at the end when it was the
   * oldest. A no-op if the track has since been saved again some other way.
   */
  fun restore(sounds: List<SavedSound>, removed: SavedSound): List<SavedSound> {
    if (isSaved(sounds, removed.entry.track.id)) return sounds
    val slot = sounds.indexOfFirst { it.savedAt < removed.savedAt }
    return if (slot < 0) {
      sounds + removed
    } else {
      sounds.toMutableList().apply { add(slot, removed) }
    }
  }
}
