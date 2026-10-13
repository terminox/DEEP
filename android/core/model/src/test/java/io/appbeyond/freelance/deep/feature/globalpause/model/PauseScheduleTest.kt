package io.appbeyond.freelance.deep.feature.globalpause.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * Ported from Deep/DeepTests/PauseScheduleTests.swift, plus the synced clock.
 *
 * What the card counts down to once a day can hold more than one pause. The
 * regression these guard: `nextMeditationStart` used to project the same wall
 * clock 24 hours on, which was wrong twice a day as soon as there were two
 * sessions — most damagingly to someone still writing their reflection after
 * the morning session, told the next pause is tomorrow.
 */
class PauseScheduleTest {

  private val meditationStart: Instant = Instant.ofEpochSecond(1_788_000_000)

  private fun schedule(nextOccurrenceMeditationStart: Instant? = null): PauseSchedule {
    val lobby = meditationStart.minus(Duration.ofMinutes(10))
    val welcome = meditationStart.minusSeconds(10)
    val feedback = meditationStart.plus(Duration.ofMinutes(10))
    val end = meditationStart.plus(Duration.ofMinutes(20))
    return PauseSchedule(
      pauseDate = "2026-09-05",
      timezone = "Asia/Bangkok",
      phases = listOf(
        PausePhaseWindow(PausePhaseKey.Lobby, lobby, welcome),
        PausePhaseWindow(PausePhaseKey.Welcome, welcome, meditationStart),
        PausePhaseWindow(PausePhaseKey.Meditation, meditationStart, feedback),
        PausePhaseWindow(PausePhaseKey.Feedback, feedback, end),
      ),
      lobbyAudioUrl = null,
      lobbyDuration = Duration.ofSeconds(262),
      meditationAudioUrl = null,
      meditationDuration = Duration.ofMinutes(10),
      nextOccurrenceMeditationStart = nextOccurrenceMeditationStart,
    )
  }

  @Test
  @DisplayName("While this occurrence is still ahead, it is what comes next")
  fun thisOccurrenceWhileAhead() {
    val schedule = schedule(nextOccurrenceMeditationStart = meditationStart.plus(Duration.ofHours(12)))
    assertEquals(meditationStart, schedule.nextMeditationStart(meditationStart.minus(Duration.ofMinutes(5))))
  }

  @Test
  @DisplayName("Inside the reflection phase, the card names the evening session, not tomorrow")
  fun followsTheServersNextOccurrence() {
    val tonight = meditationStart.plus(Duration.ofHours(12))
    val schedule = schedule(nextOccurrenceMeditationStart = tonight)
    assertEquals(tonight, schedule.nextMeditationStart(meditationStart.plus(Duration.ofMinutes(15))))
  }

  @Test
  @DisplayName("A server that runs one pause a day still projects tomorrow")
  fun projectsTomorrowWithoutTheField() {
    val schedule = schedule(nextOccurrenceMeditationStart = null)
    assertEquals(
      meditationStart.plus(Duration.ofHours(24)),
      schedule.nextMeditationStart(meditationStart.plusSeconds(60)),
    )
  }

  @Test
  @DisplayName("A next occurrence at or before this one is ignored")
  fun ignoresANonAdvancingNextOccurrence() {
    val schedule = schedule(nextOccurrenceMeditationStart = meditationStart)
    assertEquals(
      meditationStart.plus(Duration.ofHours(24)),
      schedule.nextMeditationStart(meditationStart.plusSeconds(60)),
    )
  }

  @Test
  @DisplayName("Without a meditation phase there is nothing to count down to")
  fun nullWithoutAMeditation() {
    val empty = PauseSchedule(
      pauseDate = "2026-09-05",
      timezone = "Asia/Bangkok",
      phases = emptyList(),
      lobbyAudioUrl = null,
      lobbyDuration = Duration.ZERO,
      meditationAudioUrl = null,
      meditationDuration = Duration.ZERO,
    )
    assertNull(empty.nextMeditationStart(meditationStart))
    assertNull(empty.windowEnd)
  }

  @Test
  @DisplayName("windowEnd is the last phase edge")
  fun windowEndIsTheLastEdge() {
    assertEquals(meditationStart.plus(Duration.ofMinutes(20)), schedule().windowEnd)
  }

  @Test
  @DisplayName("The next boundary is the nearest edge strictly ahead, then none")
  fun nextBoundary() {
    val schedule = schedule()
    assertEquals(meditationStart, schedule.nextBoundary(meditationStart.minusSeconds(5)))
    assertEquals(meditationStart.plus(Duration.ofMinutes(10)), schedule.nextBoundary(meditationStart))
    assertNull(schedule.nextBoundary(meditationStart.plus(Duration.ofMinutes(20))))
  }

  @Test
  @DisplayName("The schedule line reads in the member's own clock, with no zone named")
  fun scheduleLineIsLocal() {
    // The evening session: 20:40 Bangkok on 6 September 2026.
    val bangkok = ZoneId.of("Asia/Bangkok")
    val target = LocalDateTime.of(2026, 9, 6, 20, 40).atZone(bangkok).toInstant()
    val earlier = target.minus(Duration.ofHours(2)) // 18:40 the same evening

    val inBangkok = PauseScheduleLine.of(target, earlier, bangkok)
    assertEquals(PauseScheduleLine.Day.Today, inBangkok.day)
    assertEquals(LocalTime.of(20, 40), inBangkok.time)

    // The same instant read in Auckland, where it has already tipped into
    // tomorrow. Two members seeing different words for one moment is the point.
    val fromAuckland = PauseScheduleLine.of(target, earlier, ZoneId.of("Pacific/Auckland"))
    assertEquals(PauseScheduleLine.Day.Tomorrow, fromAuckland.day)
    assertEquals(LocalTime.of(1, 40), fromAuckland.time)
  }

  @Test
  @DisplayName("The synced clock follows the server, without touching the device")
  fun syncedClockFollowsTheServer() {
    val device = Clock.fixed(Instant.ofEpochSecond(1_000), ZoneOffset.UTC)
    val clock = SyncedClock(device)
    assertEquals(Instant.ofEpochSecond(1_000), clock.now())

    // Dev time travel: the server reports a pinned instant days away.
    clock.sync(Instant.ofEpochSecond(1_000 + 86_400 * 3))
    assertEquals(Duration.ofDays(3), clock.serverOffset)
    assertEquals(Instant.ofEpochSecond(1_000 + 86_400 * 3), clock.now())
    assertEquals(clock.now(), clock.instant())

    // A device a minute fast is corrected back.
    clock.sync(Instant.ofEpochSecond(940))
    assertEquals(Instant.ofEpochSecond(940), clock.now())
  }

  @Test
  @DisplayName("Only a two-letter region is sent as the member's country")
  fun countryIsAlpha2OrNothing() {
    assertEquals("TH", PauseCountry.normalize("th"))
    assertEquals("US", PauseCountry.normalize("US"))
    assertNull(PauseCountry.normalize("419")) // Latin America, a UN M.49 region
    assertNull(PauseCountry.normalize(""))
    assertNull(PauseCountry.normalize(null))
  }
}
