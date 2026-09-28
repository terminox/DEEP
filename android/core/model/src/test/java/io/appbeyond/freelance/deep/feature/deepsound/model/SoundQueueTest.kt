package io.appbeyond.freelance.deep.feature.deepsound.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

/**
 * Ported from the transport-rule cases in Deep's `SoundPlayer`/
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
}
