package io.appbeyond.freelance.deep.feature.practice.model

import java.time.LocalDate
import java.util.Locale
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.jupiter.api.DisplayName
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

  // MARK: - A Global Pause sat today (B23, iOS PR #62)

  @Test
  @DisplayName("A pause marked today counts; yesterday's pause does not")
  fun pauseDayCountsOnlyToday() {
    val today = LocalDate.of(2026, 7, 23)
    assertTrue(PracticeMath.hasPauseDay(setOf(today), zone, clock))
    assertFalse(PracticeMath.hasPauseDay(setOf(today.minusDays(1)), zone, clock))
    assertFalse(PracticeMath.hasPauseDay(emptySet(), zone, clock))
  }

  @Test
  @DisplayName("A pause that ends past midnight belongs to the day its marker landed in")
  fun pauseMarkerPastMidnightIsTheNewDay() {
    // The claim's answer landed at 00:04 on the 24th.
    val marker = setOf(LocalDate.ofInstant(date(2026, 7, 24, 0, 4), zone))
    val lateOnTheEve = Clock.fixed(date(2026, 7, 23, 23, 50), zone)
    val nextMorning = Clock.fixed(date(2026, 7, 24, 8, 0), zone)
    assertFalse(PracticeMath.hasPauseDay(marker, zone, lateOnTheEve))
    assertTrue(PracticeMath.hasPauseDay(marker, zone, nextMorning))
  }

  @Test
  @DisplayName("A pause sat today still counts on a Thai device's Buddhist calendar")
  fun pauseDayIgnoresBuddhistDefault() {
    val original = Locale.getDefault()
    try {
      Locale.setDefault(Locale.forLanguageTag("th-TH-u-ca-buddhist"))
      // Keys are ISO-8601, parsed with the ISO chronology whatever the locale.
      val key = LocalDate.parse("2026-07-23")
      assertTrue(PracticeMath.hasPauseDay(setOf(key), zone, clock))
    } finally {
      Locale.setDefault(original)
    }
  }
}
