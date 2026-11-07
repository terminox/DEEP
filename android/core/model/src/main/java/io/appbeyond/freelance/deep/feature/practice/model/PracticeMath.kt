package io.appbeyond.freelance.deep.feature.practice.model

import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeParseException
import kotlin.math.max

/**
 * The practice rhythm across today's boundary: the run of consecutive days
 * before today, and as it stands now. `after > before` exactly when today is
 * the day that extended it — the ending names that a return.
 *
 * Ported from `ContinuityTransition` in PracticeMath.swift.
 *
 * @property before consecutive practice days ending yesterday.
 * @property after consecutive practice days ending today — or, while today has
 *   no practice yet, the run still alive from yesterday (the same as [before]).
 */
data class ContinuityTransition(val before: Int, val after: Int) {
  val returnedToday: Boolean get() = after > before
}

/**
 * Pure aggregate math over the practice journal. The server keeps a dumb log;
 * everything the garden shows — today's minutes, streaks — is derived here,
 * in the user's own calendar, so day boundaries follow the device timezone.
 *
 * Minutes and the session cap are DEEP Sessions only. The rhythm (streaks,
 * continuity) counts *any* practice day: a finished session, a sound listened
 * to its end, or a Global Pause the server counted — the `extraDays` every
 * rhythm function takes.
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
    extraDays: Set<LocalDate> = emptySet(),
  ): Int {
    val days = practiceDays(completions, zone) + extraDays
    val today = clock.instant().atZone(zone).toLocalDate()
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
    extraDays: Set<LocalDate> = emptySet(),
  ): Int {
    val days = (practiceDays(completions, zone) + extraDays).sorted()
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

  /**
   * The run before today and the run now — see [ContinuityTransition].
   *
   * @param extraDays days kept by something other than a session — a sound
   *   listened to its end, an attended Global Pause, the server's activity days.
   */
  fun continuityTransition(
    completions: List<PracticeCompletion>,
    zone: ZoneId,
    clock: Clock,
    extraDays: Set<LocalDate> = emptySet(),
  ): ContinuityTransition {
    val days = practiceDays(completions, zone) + extraDays
    val today = clock.instant().atZone(zone).toLocalDate()
    var cursor = today.minusDays(1)
    var before = 0
    while (days.contains(cursor)) {
      before++
      cursor = cursor.minusDays(1)
    }
    return ContinuityTransition(before = before, after = if (days.contains(today)) before + 1 else before)
  }

  /**
   * Whether a Global Pause the server counted was sat on today's local day —
   * iOS's `hasActivity(.pause, in:calendar:now:)`. [pauseDays] are ISO
   * (Gregorian) keys stamped as each claim's answer landed, so a sit whose
   * answer lands past midnight belongs to the new day, and a Thai device's
   * Buddhist calendar never shifts them.
   */
  fun hasPauseDay(pauseDays: Set<LocalDate>, zone: ZoneId, clock: Clock): Boolean =
    clock.instant().atZone(zone).toLocalDate() in pauseDays

  /**
   * The day a "YYYY-MM-DD" key names — a server activity day or a stored
   * marker — or null for a key that doesn't parse (an impossible date
   * included).
   *
   * The key is always an ISO (Gregorian) date, whatever calendar the device
   * reads in: [LocalDate.parse] never consults the locale, so a Thai phone's
   * Buddhist calendar can't turn "2026" into 2026 BE (1483 AD), the bug iOS
   * guards against with an explicit Gregorian calendar.
   */
  fun day(fromKey: String): LocalDate? = try {
    LocalDate.parse(fromKey)
  } catch (_: DateTimeParseException) {
    null
  }

  /** Every key that names a day, as days — see [day]. */
  fun days(fromKeys: Collection<String>): Set<LocalDate> = fromKeys.mapNotNullTo(HashSet()) { day(it) }

  /** Distinct local-midnight days with at least one completion. */
  private fun practiceDays(completions: List<PracticeCompletion>, zone: ZoneId): Set<LocalDate> =
    completions.map { it.completedAt.atZone(zone).toLocalDate() }.toSet()

  private fun sameDay(a: Instant, b: Instant, zone: ZoneId): Boolean =
    a.atZone(zone).toLocalDate() == b.atZone(zone).toLocalDate()
}
