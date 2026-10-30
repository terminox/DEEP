package io.appbeyond.freelance.deep.feature.deepsound.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.random.Random
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The queue rules every DEEP Sound player shares: a playlist plays through in
 * order and stops, Repeat All runs it again, Repeat One holds a track, the
 * skip buttons move the way Apple Music's do, Shuffle deals every track once,
 * and a track with no audio is never what plays.
 *
 * Ported from Deep/DeepTests/SoundQueueTests.swift, plus the helpers Android
 * keeps on the same type (seeking, progress, and which entries may queue).
 */
class SoundQueueTest {

  private val collection = SoundCollection(
    id = "fixture",
    title = "Queue fixture",
    subtitle = "",
    palette = null,
    imageUrl = null,
  )

  /** `count` tracks named "0", "1", …; those in [silent] have no audio. */
  private fun entries(count: Int, silent: Set<Int> = emptySet()): List<SoundQueueEntry> =
    (0 until count).map { index ->
      SoundQueueEntry(
        track = SoundTrack(
          id = "$index",
          title = "$index",
          durationSeconds = 60,
          audioUrl = if (index in silent) null else "https://deep.test/$index.mp3",
        ),
        collection = collection,
      )
    }

  /** A queue on the streaming player's rule. Seeded, so a failure replays exactly. */
  private fun queueOf(
    entries: List<SoundQueueEntry>,
    at: Int? = 0,
    shuffled: Boolean = false,
    repeatMode: RepeatMode = RepeatMode.Off,
    seed: Int = 7,
  ): SoundQueue<SoundQueueEntry> = SoundQueue.start(
    entries,
    startIndex = at,
    shuffled = shuffled,
    repeatMode = repeatMode,
    canPlay = SoundQueue.hasAudio,
    random = Random(seed),
  )

  private val SoundQueue<SoundQueueEntry>.currentId: String? get() = current?.track?.id
  private val SoundQueue<SoundQueueEntry>.upcomingId: String? get() = upcoming?.track?.id

  // MARK: - Natural end

  @Test
  @DisplayName("Repeat off plays the playlist through in order, then stops on the first track")
  fun repeatOffStopsAtTheEnd() {
    var queue = queueOf(entries(3))
    assertEquals("0", queue.currentId)
    val first = queue.advanceAfterEnd()
    assertTrue(first.carriesOn)
    queue = first.queue
    assertEquals("1", queue.currentId)
    val second = queue.advanceAfterEnd()
    assertTrue(second.carriesOn)
    queue = second.queue
    assertEquals("2", queue.currentId)
    assertNull(queue.upcoming)
    val pastTheEnd = queue.advanceAfterEnd()
    assertFalse(pastTheEnd.carriesOn)
    assertEquals("0", pastTheEnd.queue.currentId)
  }

  @Test
  @DisplayName("Repeat All runs the playlist again after the last track")
  fun repeatAllWraps() {
    val queue = queueOf(entries(3), at = 2, repeatMode = RepeatMode.All)
    assertEquals("0", queue.upcomingId)
    val (next, continued) = queue.advanceAfterEnd()
    assertTrue(continued)
    assertEquals("0", next.currentId)
  }

  @Test
  @DisplayName("Repeat One holds the current track")
  fun repeatOneHolds() {
    val queue = queueOf(entries(3), at = 1, repeatMode = RepeatMode.One)
    assertEquals("1", queue.upcomingId)
    val (next, continued) = queue.advanceAfterEnd()
    assertTrue(continued)
    assertEquals("1", next.currentId)
  }

  @Test
  @DisplayName("A single track repeats only when asked to")
  fun singleTrack() {
    val off = queueOf(entries(1))
    assertNull(off.upcoming)
    assertFalse(off.advanceAfterEnd().carriesOn)

    val all = queueOf(entries(1), repeatMode = RepeatMode.All)
    assertEquals("0", all.upcomingId)
    assertTrue(all.advanceAfterEnd().carriesOn)
  }

  @Test
  @DisplayName("Changing the mode mid-track changes what comes next")
  fun modeChangeRetargetsUpcoming() {
    val queue = queueOf(entries(3), at = 2)
    assertNull(queue.upcoming)
    assertEquals("0", queue.withRepeatMode(RepeatMode.All).upcomingId)
    assertEquals("2", queue.withRepeatMode(RepeatMode.One).upcomingId)
  }

  @Test
  @DisplayName("The Repeat control steps off, all, one, and round again")
  fun repeatCycle() {
    assertEquals(RepeatMode.All, RepeatMode.Off.next)
    assertEquals(RepeatMode.One, RepeatMode.All.next)
    assertEquals(RepeatMode.Off, RepeatMode.One.next)
  }

  @Test
  @DisplayName("A stored Repeat mode reads back, and anything else reads as nothing")
  fun repeatModeStorage() {
    RepeatMode.entries.forEach { assertEquals(it, RepeatMode.of(it.raw)) }
    assertNull(RepeatMode.of(null))
    assertNull(RepeatMode.of("sometimes"))
  }

  // MARK: - Skipping

  @Test
  @DisplayName("Next moves on even in Repeat One")
  fun nextLeavesRepeatOne() {
    val (next, carriesOn) = queueOf(entries(3), repeatMode = RepeatMode.One).skipForward()
    assertTrue(carriesOn)
    assertEquals("1", next.currentId)
  }

  @Test
  @DisplayName("Next from the last track wraps, carrying on only under Repeat All")
  fun nextWrapsAtTheEnd() {
    val (off, offCarriesOn) = queueOf(entries(3), at = 2).skipForward()
    assertFalse(offCarriesOn)
    assertEquals("0", off.currentId)

    val (one, oneCarriesOn) = queueOf(entries(3), at = 2, repeatMode = RepeatMode.One).skipForward()
    assertFalse(oneCarriesOn)
    assertEquals("0", one.currentId)

    val (all, allCarriesOn) = queueOf(entries(3), at = 2, repeatMode = RepeatMode.All).skipForward()
    assertTrue(allCarriesOn)
    assertEquals("0", all.currentId)
  }

  @Test
  @DisplayName("Previous steps back, and wraps from the first track only under Repeat All")
  fun previousAtTheStart() {
    val (middle, middleMoved) = queueOf(entries(3), at = 1).skipBack()
    assertTrue(middleMoved)
    assertEquals("0", middle.currentId)

    val (off, offMoved) = queueOf(entries(3)).skipBack()
    assertFalse(offMoved)
    assertEquals("0", off.currentId)

    val (one, oneMoved) = queueOf(entries(3), repeatMode = RepeatMode.One).skipBack()
    assertFalse(oneMoved)
    assertEquals("0", one.currentId)

    val (all, allMoved) = queueOf(entries(3), repeatMode = RepeatMode.All).skipBack()
    assertTrue(allMoved)
    assertEquals("2", all.currentId)
  }

  // MARK: - Shuffle

  @Test
  @DisplayName("Shuffle plays every track exactly once, starting from the chosen one")
  fun shuffleIsAPermutation() {
    var queue = queueOf(entries(8), at = 5, shuffled = true)
    assertTrue(queue.isShuffled)
    val played = mutableListOf(queue.currentId!!)
    while (true) {
      val (next, continued) = queue.advanceAfterEnd()
      if (!continued) break
      queue = next
      played += queue.currentId!!
    }
    assertEquals("5", played.first())
    assertEquals(8, played.size)
    assertEquals((0 until 8).map(Int::toString).toSet(), played.toSet())
    assertNotEquals((0 until 8).map(Int::toString), played, "seed 7 deals a real shuffle")
  }

  @Test
  @DisplayName("Shuffle with no start begins on a random track")
  fun shuffleRandomStart() {
    val starts = (0 until 20).map { seed ->
      queueOf(entries(8), at = null, shuffled = true, seed = seed).currentId
    }.toSet()
    assertTrue(starts.size > 1)
  }

  @Test
  @DisplayName("Shuffle with no start never begins on a track with no audio")
  fun shuffleRandomStartIsPlayable() {
    repeat(20) { seed ->
      val queue = queueOf(entries(6, silent = setOf(0, 2, 3, 5)), at = null, shuffled = true, seed = seed)
      assertTrue(queue.currentId in setOf("1", "4"))
    }
  }

  @Test
  @DisplayName("Turning shuffle on keeps the current track; turning it off resumes the original order")
  fun toggleShuffleKeepsTheCurrentTrack() {
    val random = Random(11)
    val shuffled = queueOf(entries(6), at = 3).withShuffle(true, random)
    assertTrue(shuffled.isShuffled)
    assertEquals("3", shuffled.currentId)
    assertEquals(0, shuffled.position)

    val unshuffled = shuffled.withShuffle(false, random)
    assertFalse(unshuffled.isShuffled)
    assertEquals("3", unshuffled.currentId)
    assertEquals("4", unshuffled.upcomingId)
  }

  @Test
  @DisplayName("A play order another holder dealt is taken as it stands")
  fun adoptingAnotherHoldersOrder() {
    val queue = queueOf(entries(4))
    val adopted = queue.adopting(listOf(2, 0, 3, 1), currentIndex = 3, RepeatMode.All, isShuffled = true)!!
    assertEquals("3", adopted.currentId)
    assertEquals("1", adopted.upcomingId)
    assertEquals(RepeatMode.All, adopted.repeatMode)
    assertTrue(adopted.isShuffled)

    assertNull(queue.adopting(listOf(0, 1, 2), currentIndex = 0, RepeatMode.Off, isShuffled = false))
    assertNull(queue.adopting(listOf(0, 1, 1, 2), currentIndex = 0, RepeatMode.Off, isShuffled = false))
    assertNull(queue.adopting(listOf(0, 1, 2, 3), currentIndex = 9, RepeatMode.Off, isShuffled = false))
  }

  // MARK: - Tracks with no audio

  @Test
  @DisplayName("A track with no audio is skipped, never played")
  fun silentTracksAreSkipped() {
    val queue = queueOf(entries(3, silent = setOf(1)))
    assertEquals("2", queue.upcomingId)
    val (next, continued) = queue.advanceAfterEnd()
    assertTrue(continued)
    assertEquals("2", next.currentId)
    val (back, moved) = next.skipBack()
    assertTrue(moved)
    assertEquals("0", back.currentId)
  }

  @Test
  @DisplayName("Starting on a track with no audio moves on to one that has it")
  fun silentStartMovesOn() {
    assertEquals("2", queueOf(entries(3, silent = setOf(0, 1))).currentId)
  }

  @Test
  @DisplayName("A queue where nothing can play stops instead of spinning")
  fun allSilentStops() {
    val queue = queueOf(entries(3, silent = setOf(0, 1, 2)), repeatMode = RepeatMode.All)
    assertNull(queue.upcoming)
    assertFalse(queue.advanceAfterEnd().carriesOn)
    assertFalse(queue.skipForward().carriesOn)
    assertFalse(queue.skipUnplayable().carriesOn)
  }

  @Test
  @DisplayName("A track that fails to load moves on, past Repeat One")
  fun failedTrackMovesOn() {
    val (next, movedOn) = queueOf(entries(3), repeatMode = RepeatMode.One).skipUnplayable()
    assertTrue(movedOn)
    assertEquals("1", next.currentId)

    val (last, lastMovedOn) = queueOf(entries(3), at = 2).skipUnplayable()
    assertFalse(lastMovedOn)
    assertEquals("0", last.currentId)

    val (wrapped, wrappedMovedOn) = queueOf(entries(3), at = 2, repeatMode = RepeatMode.All).skipUnplayable()
    assertTrue(wrappedMovedOn)
    assertEquals("0", wrapped.currentId)
  }

  @Test
  @DisplayName("An empty queue has nothing to play and nowhere to go, but keeps its Repeat")
  fun emptyQueue() {
    val queue = SoundQueue.empty(RepeatMode.All, SoundQueue.hasAudio)
    assertTrue(queue.isEmpty)
    assertNull(queue.current)
    assertNull(queue.upcoming)
    assertFalse(queue.skipForward().carriesOn)
    assertFalse(queue.skipBack().carriesOn)
    assertEquals(RepeatMode.All, queue.replacing(entries(2), 1, shuffled = false, Random(1)).repeatMode)
  }

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

  // MARK: - playable (DEEP Premium locks, and tracks with no audio)

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
    assertEquals("t3", start?.entries?.get(start.index!!)?.track?.id)
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
    var played = queueOf(start.entries, at = start.index, repeatMode = RepeatMode.All)
    repeat(start.entries.size * 2) {
      played = played.skipForward().queue
      assertFalse(played.current!!.track.isLocked)
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
  @DisplayName("once anything has audio, tracks without any leave the queue too")
  fun playableDropsSilentTracksBesideAudibleOnes() {
    val start = SoundQueue.playable(entries(4, silent = setOf(0, 2)), startIndex = 2)
    assertEquals(listOf("1", "3"), ids(start))
    assertEquals("3", start?.entries?.get(start.index!!)?.track?.id)
  }

  @Test
  @DisplayName("a queue with no audio at all is kept whole")
  fun playableKeepsAnAllSilentQueue() {
    val start = SoundQueue.playable(entries(3, silent = setOf(0, 1, 2)), startIndex = 1)
    assertEquals(listOf("0", "1", "2"), ids(start))
    assertEquals(1, start?.index)
  }

  @Test
  @DisplayName("a shuffle's missing start stays missing")
  fun playableKeepsANullStart() {
    val start = SoundQueue.playable(queue(true, false, false), startIndex = null)
    assertEquals(listOf("t1", "t2"), ids(start))
    assertNull(start?.index)
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
