package io.appbeyond.freelance.deep.feature.reminders.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/ReminderScheduleTests.swift.
 *
 * The reminder's date maths, tested as the pure function it is — the
 * `PracticeMath` pattern. Everything here runs off a fixed [ZonedDateTime],
 * so no test depends on when it runs.
 *
 * `identifiersAreStablePerDay` is not ported: Android arms one alarm at a
 * time and has no per-day request identifiers. `copyRotatesDaily` is ported
 * against [ReminderCopy.indexFor], the pick the string resources are read
 * through. The spring-forward cases are Android's own — iOS has no test for
 * them because Asia/Bangkok keeps no DST.
 */
class ReminderScheduleTest {
  private val zone: ZoneId = ZoneId.of("Asia/Bangkok")

  private fun date(iso: String): ZonedDateTime =
    ZonedDateTime.parse(iso).withZoneSameInstant(zone)

  private val enabled = DailyReminder(isEnabled = true, hour = 21, minute = 0)

  @Test
  @DisplayName("a disabled reminder queues nothing")
  fun disabledQueuesNothing() {
    val occurrences = ReminderSchedule.occurrences(
      after = date("2026-09-01T08:00:00+07:00"),
      reminder = DailyReminder(isEnabled = false, hour = 21, minute = 0),
      practisedToday = false,
    )
    assertTrue(occurrences.isEmpty())
  }

  @Test
  @DisplayName("fills the whole window, one per day")
  fun fillsWindow() {
    val occurrences = ReminderSchedule.occurrences(
      after = date("2026-09-01T08:00:00+07:00"),
      reminder = enabled,
      practisedToday = false,
    )
    assertEquals(ReminderSchedule.horizon, occurrences.size)

    val days = occurrences.map { it.toLocalDate() }.toSet()
    assertEquals(occurrences.size, days.size, "each occurrence falls on its own day")

    // Every one lands on the chosen clock face.
    for (occurrence in occurrences) {
      assertEquals(21, occurrence.hour)
      assertEquals(0, occurrence.minute)
    }
  }

  @Test
  @DisplayName("today is included when the time is still ahead")
  fun includesTodayBeforeTheHour() {
    val now = date("2026-09-01T08:00:00+07:00")
    val occurrences = ReminderSchedule.occurrences(after = now, reminder = enabled, practisedToday = false)
    assertEquals(now.toLocalDate(), occurrences[0].toLocalDate())
  }

  @Test
  @DisplayName("today is skipped once its time has passed")
  fun skipsTodayAfterTheHour() {
    val now = date("2026-09-01T21:30:00+07:00")
    val occurrences = ReminderSchedule.occurrences(after = now, reminder = enabled, practisedToday = false)
    assertFalse(occurrences[0].toLocalDate() == now.toLocalDate())
    assertEquals(ReminderSchedule.horizon, occurrences.size, "the window still fills")
  }

  @Test
  @DisplayName("a day whose practice is done stays quiet")
  fun skipsTodayWhenGoalMet() {
    val now = date("2026-09-01T08:00:00+07:00")
    val occurrences = ReminderSchedule.occurrences(after = now, reminder = enabled, practisedToday = true)
    assertFalse(occurrences[0].toLocalDate() == now.toLocalDate())
    // Tomorrow is not skipped — only today can be known to be complete.
    val tomorrow = now.plusDays(1)
    assertEquals(tomorrow.toLocalDate(), occurrences[0].toLocalDate())
  }

  @Test
  @DisplayName("the window stays under the system's 64-request cap")
  fun staysUnderSystemCap() {
    assertTrue(ReminderSchedule.horizon < 64)
  }

  @Test
  @DisplayName("every occurrence is in the future")
  fun allFuture() {
    val now = date("2026-09-01T20:59:59+07:00")
    val occurrences = ReminderSchedule.occurrences(after = now, reminder = enabled, practisedToday = false)
    assertTrue(occurrences.all { it.isAfter(now) })
  }

  @Test
  @DisplayName("copy rotates by day and holds still within one")
  fun copyRotatesDaily() {
    val day = date("2026-09-01T21:00:00+07:00").toLocalDate()
    assertEquals(ReminderCopy.indexFor(day), ReminderCopy.indexFor(date("2026-09-01T23:00:00+07:00").toLocalDate()))

    // A week of consecutive days should exhaust the pool rather than repeat.
    val week = (0 until ReminderCopy.poolSize).map { ReminderCopy.indexFor(day.plusDays(it.toLong())) }
    assertEquals(ReminderCopy.poolSize, week.toSet().size)
    assertTrue(week.all { it in 0 until ReminderCopy.poolSize })
    // Days before the epoch still land inside the pool.
    assertTrue(ReminderCopy.indexFor(LocalDate.of(1960, 1, 1)) in 0 until ReminderCopy.poolSize)
  }

  // MARK: - Daylight saving

  private val newYork: ZoneId = ZoneId.of("America/New_York")

  @Test
  @DisplayName("a wall time skipped by spring-forward skips that day, as iOS does")
  fun springForwardGapSkipsTheDay() {
    // 2026-03-08: New York's clocks jump from 02:00 to 03:00.
    val now = ZonedDateTime.of(2026, 3, 7, 0, 0, 0, 0, newYork)
    val occurrences = ReminderSchedule.occurrences(
      after = now,
      reminder = DailyReminder(isEnabled = true, hour = 2, minute = 30),
      practisedToday = false,
    )

    val days = occurrences.map { it.toLocalDate() }
    assertTrue(LocalDate.of(2026, 3, 7) in days)
    assertFalse(LocalDate.of(2026, 3, 8) in days, "02:30 does not exist that night")
    assertTrue(LocalDate.of(2026, 3, 9) in days)
    // Never resolved forward to 03:30: every occurrence is on the chosen face.
    assertTrue(occurrences.all { it.hour == 2 && it.minute == 30 })
    assertEquals(ReminderSchedule.horizon, occurrences.size, "the bounded walk still fills the window")
  }

  @Test
  @DisplayName("a wall time doubled by fall-back fires once, at the earlier instant")
  fun fallBackOverlapFiresOnce() {
    // 2026-11-01: New York's 01:00–02:00 happens twice.
    val now = ZonedDateTime.of(2026, 10, 31, 12, 0, 0, 0, newYork)
    val occurrences = ReminderSchedule.occurrences(
      after = now,
      reminder = DailyReminder(isEnabled = true, hour = 1, minute = 30),
      practisedToday = false,
      limit = 3,
    )

    val sunday = occurrences.filter { it.toLocalDate() == LocalDate.of(2026, 11, 1) }
    assertEquals(1, sunday.size)
    assertEquals(-4 * 3600, sunday.single().offset.totalSeconds, "the first 01:30, still on daylight time")
  }

  @Test
  @DisplayName("a time outside the gap is untouched on the spring-forward day")
  fun springForwardDayKeepsOtherTimes() {
    val now = ZonedDateTime.of(2026, 3, 7, 12, 0, 0, 0, newYork)
    val occurrences = ReminderSchedule.occurrences(after = now, reminder = enabled, practisedToday = false, limit = 3)
    assertEquals(
      listOf(LocalDate.of(2026, 3, 7), LocalDate.of(2026, 3, 8), LocalDate.of(2026, 3, 9)),
      occurrences.map { it.toLocalDate() },
    )
  }
}
