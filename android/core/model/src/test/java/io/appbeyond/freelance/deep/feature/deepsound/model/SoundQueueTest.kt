package io.appbeyond.freelance.deep.feature.deepsound.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported from the transport-rule cases in DEEP's `SoundPlayer`/
 * `StreamingSoundPlayer` suites — `SoundQueue` is where Android centralises
 * the maths those three iOS players each repeat inline.
 */
class SoundQueueTest {

  // MARK: - clampStart

  @Test
  @DisplayName("clamps a start index into range")
  fun clampStartClampsIntoRange() {
    assertEquals(0, SoundQueue.clampStart(index = -1, size = 3))
    assertEquals(1, SoundQueue.clampStart(index = 1, size = 3))
    assertEquals(2, SoundQueue.clampStart(index = 10, size = 3))
  }

  @Test
  @DisplayName("an empty queue always starts at zero")
  fun clampStartOnEmptyQueueIsZero() {
    assertEquals(0, SoundQueue.clampStart(index = 0, size = 0))
    assertEquals(0, SoundQueue.clampStart(index = 5, size = 0))
    assertEquals(0, SoundQueue.clampStart(index = -5, size = 0))
  }

  // MARK: - nextIndex

  @Test
  @DisplayName("advances and wraps back to the start")
  fun nextIndexWraps() {
    assertEquals(1, SoundQueue.nextIndex(index = 0, size = 3))
    assertEquals(0, SoundQueue.nextIndex(index = 2, size = 3))
  }

  @Test
  @DisplayName("a single-item queue always advances to itself")
  fun nextIndexSingleItem() {
    assertEquals(0, SoundQueue.nextIndex(index = 0, size = 1))
  }

  // MARK: - previous

  @Test
  @DisplayName("past the restart threshold, previous restarts the track")
  fun previousPastThresholdRestarts() {
    val result = SoundQueue.previous(elapsed = 3.01, index = 2, size = 5)
    assertEquals(SoundQueue.Previous.Restart, result)
  }

  @Test
  @DisplayName("at exactly the restart threshold, previous still goes back a track")
  fun previousAtExactThresholdGoesToPreviousTrack() {
    val result = SoundQueue.previous(elapsed = 3.0, index = 2, size = 5)
    assertEquals(SoundQueue.Previous.GoTo(1), result)
  }

  @Test
  @DisplayName("previous from the first track wraps to the last")
  fun previousFromFirstTrackWrapsToLast() {
    val result = SoundQueue.previous(elapsed = 1.0, index = 0, size = 5)
    assertEquals(SoundQueue.Previous.GoTo(4), result)
  }

  @Test
  @DisplayName("a single-item queue's previous goes back to itself")
  fun previousSingleItemGoesToItself() {
    val result = SoundQueue.previous(elapsed = 1.0, index = 0, size = 1)
    assertEquals(SoundQueue.Previous.GoTo(0), result)
  }

  // MARK: - seekTarget

  @Test
  @DisplayName("seek target clamps a fraction below zero")
  fun seekTargetClampsBelowZero() {
    assertEquals(0.0, SoundQueue.seekTarget(fraction = -0.5, duration = 100.0))
  }

  @Test
  @DisplayName("seek target clamps a fraction above one")
  fun seekTargetClampsAboveOne() {
    assertEquals(100.0, SoundQueue.seekTarget(fraction = 1.5, duration = 100.0))
  }

  @Test
  @DisplayName("seek target scales a fraction within range")
  fun seekTargetScalesWithinRange() {
    assertEquals(50.0, SoundQueue.seekTarget(fraction = 0.25, duration = 200.0))
  }

  // MARK: - progress

  @Test
  @DisplayName("progress is zero when there is no duration to measure against")
  fun progressWithZeroDurationIsZero() {
    assertEquals(0.0, SoundQueue.progress(elapsed = 50.0, duration = 0.0))
  }

  @Test
  @DisplayName("progress clamps once elapsed runs past the duration")
  fun progressClampsPastDuration() {
    assertEquals(1.0, SoundQueue.progress(elapsed = 150.0, duration = 100.0))
  }

  @Test
  @DisplayName("progress is the elapsed fraction of the duration")
  fun progressIsTheElapsedFraction() {
    assertEquals(0.5, SoundQueue.progress(elapsed = 50.0, duration = 100.0))
  }

  // MARK: - playable (DEEP Premium locks)

  private fun queue(vararg locked: Boolean): List<SoundQueueEntry> {
    val tracks = locked.mapIndexed { i, isLocked ->
      SoundTrack(id = "t$i", title = "Track $i", durationSeconds = 60, isLocked = isLocked)
    }
    val collection = SoundCollection(
      id = "c",
      title = "Collection",
      subtitle = "",
      palette = null,
      imageUrl = null,
      tracks = tracks,
    )
    return collection.queue()
  }

  private fun ids(start: SoundQueue.Start?): List<String>? = start?.entries?.map { it.track.id }

  @Test
  @DisplayName("an all-unlocked queue plays exactly as asked")
  fun playableKeepsAnUnlockedQueue() {
    val start = SoundQueue.playable(queue(false, false, false), startIndex = 1)
    assertEquals(listOf("t0", "t1", "t2"), ids(start))
    assertEquals(1, start?.index)
  }

  @Test
  @DisplayName("locked tracks are left out of the queue, and the start keeps its track")
  fun playableDropsLockedTracks() {
    val start = SoundQueue.playable(queue(true, false, true, false), startIndex = 3)
    assertEquals(listOf("t1", "t3"), ids(start))
    assertEquals(1, start?.index)
  }

  @Test
  @DisplayName("starting on a locked track begins on the next unlocked one")
  fun playableSkipsALockedStart() {
    val start = SoundQueue.playable(queue(false, true, true, false), startIndex = 1)
    assertEquals(listOf("t0", "t3"), ids(start))
    assertEquals("t3", start?.entries?.get(start.index)?.track?.id)
  }

  @Test
  @DisplayName("a locked start at the end wraps round to the first unlocked track")
  fun playableWrapsPastALockedEnd() {
    val start = SoundQueue.playable(queue(true, false, true), startIndex = 2)
    assertEquals(listOf("t1"), ids(start))
    assertEquals(0, start?.index)
  }

  @Test
  @DisplayName("a queue with nothing unlocked plays nothing")
  fun playableAllLockedIsNull() {
    assertNull(SoundQueue.playable(queue(true, true), startIndex = 0))
    assertNull(SoundQueue.playable(emptyList(), startIndex = 0))
  }

  @Test
  @DisplayName("advancing through a playable queue never lands on a locked track")
  fun playableAdvanceNeverHitsLocked() {
    val start = SoundQueue.playable(queue(false, true, false, true, false), startIndex = 0)!!
    var index = start.index
    repeat(start.entries.size * 2) {
      index = SoundQueue.nextIndex(index, start.entries.size)
      assertFalse(start.entries[index].track.isLocked)
    }
  }

  @Test
  @DisplayName("an out-of-range start is clamped before the lock is checked")
  fun playableClampsTheStart() {
    val start = SoundQueue.playable(queue(false, false, true), startIndex = 10)
    assertEquals(listOf("t0", "t1"), ids(start))
    assertEquals(0, start?.index)
  }

  @Test
  @DisplayName("a collection reads locked when it or every track is")
  fun collectionLocksEveryTrack() {
    val free = queue(false, true).first().collection
    val allLocked = queue(true, true).first().collection
    assertFalse(free.locksEveryTrack)
    assertTrue(allLocked.locksEveryTrack)
    assertTrue(free.copy(isLocked = true).locksEveryTrack)
    assertFalse(free.copy(tracks = emptyList()).locksEveryTrack)
  }
}
