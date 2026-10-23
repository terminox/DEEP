package io.appbeyond.freelance.deep.feature.playlist.model

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTrack
import org.junit.jupiter.api.Test
import java.time.Instant
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Ported from the pure book-keeping half of Deep/DeepTests/PlaylistStoreTests.swift
 * — the optimistic-toggle ordering rules exercised there through `PlaylistStore`
 * itself, here run directly against [PlaylistSnapshot]'s free functions with no
 * coroutines, no `DataStore`, no network.
 */
class PlaylistSnapshotTest {

  private val collection = SoundCollection(
    id = "col-1",
    title = "Still Forest",
    subtitle = "Green quiet between the trees",
    palette = "meadow",
    imageUrl = null,
    tracks = emptyList(),
  )

  private fun track(id: String) = SoundTrack(id = id, title = "Track $id", durationSeconds = 300)

  private fun saved(id: String, savedAt: Instant) =
    SavedSound(itemId = "item-$id", savedAt = savedAt, entry = SoundQueueEntry(track(id), collection))

  /** 2026-07-23 12:00 UTC — an arbitrary fixed instant everything below offsets from. */
  private val now = Instant.parse("2026-07-23T12:00:00Z")

  // MARK: - isSaved

  @Test
  fun isSavedTrueWhenTrackPresent() {
    val sounds = listOf(saved("a", now))
    assertTrue(PlaylistSnapshot.isSaved(sounds, "a"))
  }

  @Test
  fun isSavedFalseWhenTrackAbsent() {
    val sounds = listOf(saved("a", now))
    assertFalse(PlaylistSnapshot.isSaved(sounds, "b"))
  }

  // MARK: - insert (a save, optimistic)

  @Test
  fun insertPlacesTheNewSoundAtTheTop() {
    val existing = listOf(saved("a", now))
    val fresh = saved("b", now.plusSeconds(1))

    val next = PlaylistSnapshot.insert(existing, fresh)
    assertEquals(listOf("b", "a"), next.map { it.entry.track.id })
  }

  @Test
  fun savingAnAlreadySavedTrackIsANoOp() {
    val existing = listOf(saved("a", now))
    val duplicate = saved("a", now.plusSeconds(60))

    assertEquals(existing, PlaylistSnapshot.insert(existing, duplicate))
  }

  // MARK: - remove (a removal, optimistic — and a refused save's rollback)

  @Test
  fun removeDropsOnlyTheMatchingTrack() {
    val existing = listOf(saved("a", now), saved("b", now))
    val next = PlaylistSnapshot.remove(existing, "a")
    assertEquals(listOf("b"), next.map { it.entry.track.id })
  }

  @Test
  fun removingAnAbsentTrackIsANoOp() {
    val existing = listOf(saved("a", now))
    assertEquals(existing, PlaylistSnapshot.remove(existing, "z"))
  }

  // MARK: - restore (a refused removal's rollback)

  @Test
  fun restorePutsARemovedSoundBackInItsOwnSlotNotAtTheTop() {
    // Newest first: a (newest) .. c (oldest); b was removed and is rolling back.
    val a = saved("a", now)
    val b = saved("b", now.minusSeconds(60))
    val c = saved("c", now.minusSeconds(120))
    val withoutB = listOf(a, c)

    val restored = PlaylistSnapshot.restore(withoutB, b)
    assertEquals(listOf("a", "b", "c"), restored.map { it.entry.track.id })
  }

  @Test
  fun restoreAppendsTheOldestEntryAtTheEnd() {
    val a = saved("a", now)
    val oldest = saved("z", now.minusSeconds(600))

    val restored = PlaylistSnapshot.restore(listOf(a), oldest)
    assertEquals(listOf("a", "z"), restored.map { it.entry.track.id })
  }

  @Test
  fun restoringAnAlreadySavedTrackIsANoOp() {
    val existing = listOf(saved("a", now))
    val next = PlaylistSnapshot.restore(existing, saved("a", now.minusSeconds(999)))
    assertEquals(existing, next)
  }
}
