package io.appbeyond.freelance.deep.feature.globalpause.model

import org.junit.jupiter.api.Test
import java.time.Duration
import java.time.Instant
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/FukuLoungeTests.swift.
 *
 * The arithmetic behind Fuku's Lounge: the hero has to match the member's own
 * hour with no gap or overlap between the four bands, and the nightly set has
 * to be a *broadcast* — one clock, so two people who walk in a minute apart
 * are in the same bar, and nobody restarts it.
 */
class FukuLoungeTest {

  // MARK: - Time of day

  @Test
  fun coversEveryHourOfTheDay() {
    for (hour in 0 until 24) assertTrue(FukuClip.ambient(hour) in FukuClip.entries)
  }

  @Test
  fun bandsMeetExactlyAtTheirBoundaries() {
    assertEquals(FukuClip.Midnight, FukuClip.ambient(4))
    assertEquals(FukuClip.Morning, FukuClip.ambient(5))
    assertEquals(FukuClip.Morning, FukuClip.ambient(11))
    assertEquals(FukuClip.Afternoon, FukuClip.ambient(12))
    assertEquals(FukuClip.Afternoon, FukuClip.ambient(16))
    assertEquals(FukuClip.Night, FukuClip.ambient(17))
    assertEquals(FukuClip.Night, FukuClip.ambient(23))
    assertEquals(FukuClip.Midnight, FukuClip.ambient(0))
  }

  @Test
  fun introIsNeverAnAmbientClip() {
    // The intro carries sound and plays once; as a background loop it would
    // blare Fuku's voice at whoever opened the lounge at lunchtime.
    for (hour in 0 until 24) assertNotEquals(FukuClip.Intro, FukuClip.ambient(hour))
  }

  @Test
  fun resourcesAreDistinctAndMatchTheBundledFiles() {
    assertEquals(FukuClip.entries.size, FukuClip.entries.map { it.resource }.toSet().size)
    assertEquals("fuku_morning", FukuClip.Morning.resource)
    assertEquals("fuku_intro", FukuClip.Intro.resource)
  }

  // MARK: - The broadcast

  private val start = Instant.ofEpochSecond(1_800_000_000)
  private val intro = Duration.ofSeconds(10)
  private val track = Duration.ofSeconds(262)

  private fun broadcast(hardStopAfter: Duration = Duration.ofSeconds(600)) =
    LoungeBroadcast(startsAt = start, introDuration = intro, trackDuration = track, hardStop = start.plus(hardStopAfter))

  private fun stage(offset: Duration, set: LoungeBroadcast = broadcast()) = set.stage(start.plus(offset))

  private fun seconds(value: Long) = Duration.ofSeconds(value)

  private fun millis(value: Long) = Duration.ofMillis(value)

  @Test
  fun isSilentBeforeItStarts() {
    assertEquals(LoungeBroadcast.Stage.Off, stage(seconds(-1)))
    assertFalse(broadcast().isOnAir(start.minusMillis(1)))
  }

  @Test
  fun opensOnTheIntroAtTheStroke() {
    assertEquals(LoungeBroadcast.Stage.Intro(Duration.ZERO), stage(Duration.ZERO))
    assertEquals(LoungeBroadcast.Stage.Intro(millis(9_900)), stage(millis(9_900)))
  }

  @Test
  fun handsOffToTheTrackWhenTheIntroEnds() {
    assertEquals(LoungeBroadcast.Stage.Music(Duration.ZERO), stage(intro))
    assertEquals(LoungeBroadcast.Stage.Music(seconds(30)), stage(intro.plus(seconds(30))))
  }

  @Test
  fun joinsLateInTheMiddleRatherThanStartingOver() {
    assertEquals(LoungeBroadcast.Stage.Music(seconds(120)), stage(intro.plus(seconds(120))))
  }

  @Test
  fun signsOffWhenTheTrackRunsOut() {
    assertEquals(
      LoungeBroadcast.Stage.Music(track.minusMillis(1)),
      stage(intro.plus(track).minusMillis(1)),
    )
    assertEquals(LoungeBroadcast.Stage.Off, stage(intro.plus(track)))
    assertEquals(LoungeBroadcast.Stage.Off, stage(intro.plus(track).plus(Duration.ofHours(1))))
  }

  @Test
  fun isCutOffAtTheHardStop() {
    val squeezed = broadcast(hardStopAfter = seconds(60))
    assertEquals(start.plusSeconds(60), squeezed.endsAt)
    assertEquals(LoungeBroadcast.Stage.Music(seconds(49)), stage(seconds(59), squeezed))
    assertEquals(LoungeBroadcast.Stage.Off, stage(seconds(60), squeezed))
  }

  @Test
  fun handoffSurvivesTheClipEndingBeforeTheClockAgrees() {
    // The player reports the intro's end a hair early; `stage` would still say
    // "intro" and the set would freeze on a clip that has stopped.
    val set = broadcast()
    val justShy = start.plus(intro).minusMillis(20)
    assertEquals(LoungeBroadcast.Stage.Intro(intro.minusMillis(20)), set.stage(justShy))
    assertEquals(LoungeBroadcast.Stage.Music(Duration.ZERO), set.stageAfterIntro(justShy))
  }

  @Test
  fun handoffAfterTheHardStopIsSilence() {
    val squeezed = broadcast(hardStopAfter = seconds(5))
    assertEquals(LoungeBroadcast.Stage.Off, squeezed.stageAfterIntro(start.plusSeconds(6)))
  }

  // MARK: - Building it from a schedule

  private fun schedule(lobbyAudioUrl: String?, lobbyDuration: Duration) = PauseSchedule(
    pauseDate = "2026-09-01",
    timezone = "Asia/Bangkok",
    phases = listOf(PausePhaseWindow(PausePhaseKey.Lobby, start, start.plusSeconds(590))),
    lobbyAudioUrl = lobbyAudioUrl,
    lobbyDuration = lobbyDuration,
    meditationAudioUrl = null,
    meditationDuration = seconds(132),
  )

  @Test
  fun buildsTheSetFromTheLobbyPhase() {
    val set = schedule("https://x/t.mp3", track).loungeBroadcast(intro)
    assertEquals(start, set?.startsAt)
    assertEquals(start.plusSeconds(590), set?.hardStop)
    assertEquals(start.plus(intro).plus(track), set?.endsAt)
  }

  @Test
  fun thereIsNoSetWithoutATrack() {
    assertNull(schedule(null, track).loungeBroadcast(intro))
  }

  @Test
  fun thereIsNoSetWithoutALength() {
    // An older server sends no length; a broadcast of unknown duration would
    // leave the badge lit until the welcome.
    assertNull(schedule("https://x/t.mp3", Duration.ZERO).loungeBroadcast(intro))
  }
}
