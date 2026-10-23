package io.appbeyond.freelance.deep.feature.practice.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import kotlin.test.assertEquals

class DayRolloverTest {

  private val bangkok = ZoneId.of("Asia/Bangkok")
  private val newYork = ZoneId.of("America/New_York")

  private fun clockAt(local: LocalDateTime, zone: ZoneId): Clock =
    Clock.fixed(local.atZone(zone).toInstant(), ZoneOffset.UTC)

  @Test
  @DisplayName("Today is the date in the given zone, not the clock's")
  fun todayFollowsZone() {
    // 23:30 UTC is already the next morning in Bangkok.
    val clock = Clock.fixed(Instant.parse("2026-10-22T23:30:00Z"), ZoneOffset.UTC)
    assertEquals(LocalDate.of(2026, 10, 23), DayRollover.today(bangkok, clock))
  }

  @Test
  @DisplayName("Late evening wakes at the coming midnight")
  fun lateEvening() {
    val clock = clockAt(LocalDateTime.of(2026, 10, 23, 23, 59, 30), bangkok)
    assertEquals(Duration.ofSeconds(30), DayRollover.untilNextDay(bangkok, clock))
  }

  @Test
  @DisplayName("Exactly midnight waits for the next one")
  fun exactlyMidnight() {
    val clock = clockAt(LocalDateTime.of(2026, 10, 23, 0, 0), bangkok)
    assertEquals(Duration.ofHours(24), DayRollover.untilNextDay(bangkok, clock))
  }

  @Test
  @DisplayName("A daylight-saving night is measured to the real boundary")
  fun daylightSaving() {
    // US clocks fall back on 1 November 2026: that day is 25 hours long.
    val clock = clockAt(LocalDateTime.of(2026, 11, 1, 0, 0), newYork)
    assertEquals(Duration.ofHours(25), DayRollover.untilNextDay(newYork, clock))
  }
}
