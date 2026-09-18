package io.appbeyond.freelance.deep.feature.practice.model

import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.UUID
import kotlin.test.assertEquals

/**
 * Ported from Deep/DeepTests/PracticeMathTests.swift.
 *
 * Deterministic aggregate math, pinned to a fixed zone/clock/now so
 * day-boundary edge cases can't drift with wherever the test machine sits.
 */
class PracticeMathTest {
  private val zone: ZoneId = ZoneId.of("Asia/Bangkok")

  /** 2026-07-23 12:00 Bangkok — a fixed "now" for every test below. */
  private val now = date(2026, 7, 23, 12, 0)

  private val clock: Clock = Clock.fixed(now, zone)

  private fun date(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0): Instant =
    ZonedDateTime.of(year, month, day, hour, minute, 0, 0, zone).toInstant()

  private fun completion(durationSeconds: Int, day: Instant): PracticeCompletion =
    PracticeCompletion(
      id = UUID.randomUUID(),
      title = "Balancing breath",
      durationSeconds = durationSeconds,
      completedAt = day,
      isSynced = true,
    )

  // MARK: - minutesToday

  @Test
  fun minutesTodayCountsOnlySameDay() {
    val yesterdayLate = date(2026, 7, 22, 23, 59)
    val todayEarly = date(2026, 7, 23, 0, 1)
    val completions = listOf(
      completion(120, yesterdayLate),
      completion(60, todayEarly),
    )

    val minutes = PracticeMath.minutesToday(completions, zone, clock)
    assertEquals(1, minutes)
  }

  @Test
  fun minutesTodaySixtySecondsReadsOneMinute() {
    val completions = listOf(completion(60, now))
    val minutes = PracticeMath.minutesToday(completions, zone, clock)
    assertEquals(1, minutes)
  }

  @Test
  fun minutesTodayEmptyIsZero() {
    val minutes = PracticeMath.minutesToday(emptyList(), zone, clock)
    assertEquals(0, minutes)
  }

  // MARK: - completionsToday

  @Test
  fun completionsTodayCountsSessionsNotMinutes() {
    val yesterdayLate = date(2026, 7, 22, 23, 59)
    val completions = listOf(
      completion(300, now),
      completion(60, date(2026, 7, 23, 8)),
      completion(600, yesterdayLate),
    )

    val count = PracticeMath.completionsToday(completions, zone, clock)
    assertEquals(2, count)
  }

  @Test
  fun completionsTodayEmptyIsZero() {
    val count = PracticeMath.completionsToday(emptyList(), zone, clock)
    assertEquals(0, count)
  }

  // MARK: - currentStreakDays

  @Test
  fun currentStreakCountsBackFromToday() {
    val completions = listOf(
      completion(60, now),
      completion(60, date(2026, 7, 22)),
      completion(60, date(2026, 7, 21)),
    )

    val streak = PracticeMath.currentStreakDays(completions, zone, clock)
    assertEquals(3, streak)
  }

  @Test
  fun currentStreakStillAliveWhenTodayEmptyButYesterdayPracticed() {
    val completions = listOf(
      completion(60, date(2026, 7, 22)),
      completion(60, date(2026, 7, 21)),
    )

    val streak = PracticeMath.currentStreakDays(completions, zone, clock)
    assertEquals(2, streak)
  }

  @Test
  fun currentStreakBrokenByMissedDayIsZero() {
    // Neither today (23rd) nor yesterday (22nd) has practice — the streak
    // that ended on the 20th is broken.
    val completions = listOf(
      completion(60, date(2026, 7, 20)),
      completion(60, date(2026, 7, 19)),
    )

    val streak = PracticeMath.currentStreakDays(completions, zone, clock)
    assertEquals(0, streak)
  }

  // MARK: - longestStreakDays

  @Test
  fun longestStreakPicksTheLongestRunOverGaps() {
    val completions = listOf(
      // A 2-day run.
      completion(60, date(2026, 7, 1)),
      completion(60, date(2026, 7, 2)),
      // A gap, then a 4-day run — the longest.
      completion(60, date(2026, 7, 10)),
      completion(60, date(2026, 7, 11)),
      completion(60, date(2026, 7, 12)),
      completion(60, date(2026, 7, 13)),
      // A single day after another gap.
      completion(60, date(2026, 7, 20)),
    )

    val longest = PracticeMath.longestStreakDays(completions, zone)
    assertEquals(4, longest)
  }

  @Test
  fun longestStreakEmptyIsZero() {
    val longest = PracticeMath.longestStreakDays(emptyList(), zone)
    assertEquals(0, longest)
  }
}
