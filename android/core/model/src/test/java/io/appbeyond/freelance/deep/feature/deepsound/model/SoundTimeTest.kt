package io.appbeyond.freelance.deep.feature.deepsound.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

/**
 * Ported from Deep/Deep/Features/DeepSound/Models/SoundContent.swift's
 * `TimeInterval.clockString` / `.minutesString`.
 */
class SoundTimeTest {

  // MARK: - clock

  @Test
  @DisplayName("zero seconds reads as 0:00")
  fun zeroSecondsReadsAsZero() {
    assertEquals("0:00", SoundTime.clock(0.0))
  }

  @Test
  @DisplayName("245 seconds reads as 4:05")
  fun typicalDurationReadsAsMinutesAndSeconds() {
    assertEquals("4:05", SoundTime.clock(245.0))
  }

  @Test
  @DisplayName("59.5 seconds rounds up into the next minute")
  fun halfSecondRoundsHalfAwayFromZero() {
    assertEquals("1:00", SoundTime.clock(59.5))
  }

  @Test
  @DisplayName("3600 seconds reads as 60:00, with no hour rollover")
  fun anHourReadsAsSixtyMinutes() {
    assertEquals("60:00", SoundTime.clock(3600.0))
  }

  @Test
  @DisplayName("negative seconds are guarded to zero")
  fun negativeSecondsIsGuardedToZero() {
    assertEquals("0:00", SoundTime.clock(-30.0))
  }

  // MARK: - minutes

  @Test
  @DisplayName("minutes rounds to the nearest whole minute")
  fun minutesRoundsToNearestMinute() {
    assertEquals(4, SoundTime.minutes(245.0))
  }

  @Test
  @DisplayName("minutes is never less than one, even for a few seconds")
  fun minutesIsAtLeastOne() {
    assertEquals(1, SoundTime.minutes(5.0))
    assertEquals(1, SoundTime.minutes(0.0))
  }

  @Test
  @DisplayName("negative seconds are guarded to a minimum of one minute")
  fun minutesNegativeIsGuardedToOne() {
    assertEquals(1, SoundTime.minutes(-120.0))
  }
}
