package io.appbeyond.freelance.deep.feature.practice.model

import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.max

/**
 * Pure aggregate math over the practice journal. The server keeps a dumb log;
 * everything the garden shows — today's minutes, streaks — is derived here,
 * in the user's own calendar, so day boundaries follow the device timezone.
 *
 * Ported from Deep/Deep/Features/Practice/Models/PracticeMath.swift. iOS
 * passes a `Calendar` (which carries the device's `TimeZone`) and an explicit
 * `now: Date` into every call. Here those two facts arrive as a [ZoneId] and a
 * [Clock] instead of being read from `ZoneId.systemDefault()` /
 * `Clock.systemDefaultZone()` — so a test can pin both exactly, the same way
 * the Swift suite pins its calendar identifier, timezone, and `now`.
 */
object PracticeMath {
  /**
   * Whole minutes practised today. Any practice at all counts for at least a
   * minute, so a single one-minute session never rounds away to nothing.
   */
  fun minutesToday(
    completions: List<PracticeCompletion>,
    zone: ZoneId,
    clock: Clock,
  ): Int {
    val now = clock.instant()
    val seconds = completions
      .filter { sameDay(it.completedAt, now, zone) }
      .sumOf { it.durationSeconds }
    if (seconds <= 0) return 0
    return max(1, seconds / 60)
  }

  /**
   * Sessions completed today — the client mirror of the server's per-day
   * session award rule (`RewardRules.deepSessionDailyLimit`), so the
   * completion beat never promises a heart the sync will not deliver.
   */
  fun completionsToday(
    completions: List<PracticeCompletion>,
    zone: ZoneId,
    clock: Clock,
  ): Int {
    val now = clock.instant()
    return completions.count { sameDay(it.completedAt, now, zone) }
  }

  /**
   * Consecutive practice days ending today — or yesterday, so a streak isn't
   * "broken" while today simply hasn't happened yet.
   */
  fun currentStreakDays(
    completions: List<PracticeCompletion>,
    zone: ZoneId,
    clock: Clock,
  ): Int {
    val days = practiceDays(completions, zone)
    val today = LocalDate.ofInstant(clock.instant(), zone)
    var cursor = if (days.contains(today)) today else today.minusDays(1)

    var streak = 0
    while (days.contains(cursor)) {
      streak++
      cursor = cursor.minusDays(1)
    }
    return streak
  }

  /**
   * The longest run of consecutive practice days ever. Plant unlocks derive
   * from this rather than the current streak, so growth never regresses.
   */
  fun longestStreakDays(
    completions: List<PracticeCompletion>,
    zone: ZoneId,
  ): Int {
    val days = practiceDays(completions, zone).sorted()
    var longest = 0
    var run = 0
    var previous: LocalDate? = null
    for (day in days) {
      run = if (previous != null && previous.plusDays(1) == day) run + 1 else 1
      longest = max(longest, run)
      previous = day
    }
    return longest
  }

  /** Distinct local-midnight days with at least one completion. */
  private fun practiceDays(completions: List<PracticeCompletion>, zone: ZoneId): Set<LocalDate> =
    completions.map { LocalDate.ofInstant(it.completedAt, zone) }.toSet()

  private fun sameDay(a: Instant, b: Instant, zone: ZoneId): Boolean =
    LocalDate.ofInstant(a, zone) == LocalDate.ofInstant(b, zone)
}
