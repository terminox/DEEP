package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.feature.globalpause.model.GlobalPauseRewardSnapshot
import io.appbeyond.freelance.deep.feature.practice.model.ContinuityTransition
import io.appbeyond.freelance.deep.feature.rewards.model.RewardReceipt
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.Duration
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

/**
 * One visit to the live pause — the logic half of iOS's
 * `GlobalPauseSessionController` and `GlobalPauseCompletionView`: the
 * meditation ends on whichever trigger comes first, the books are frozen
 * before the claim moves them, presence is released after the claim's
 * closing beat, and the ritual waits for the claim to settle.
 */
class GlobalPauseVisitTest {

  private class Harness(
    val remote: FixturePauseEventRemote,
    val session: GlobalPauseSession,
    val audio: MockGlobalPauseAudioPlayer,
    val visit: GlobalPauseVisit,
    val snapshots: MutableList<GlobalPauseRewardSnapshot>,
  )

  /** A visit to a meditation that started [startedAgo] ago. */
  private suspend fun TestScope.harness(
    startedAgo: Duration = Duration.ofMinutes(5),
    audioUrl: String? = "https://x/meditation.mp3",
    snapshotDelay: Duration = Duration.ZERO,
  ): Harness {
    val remote = FixturePauseEventRemote(
      scheduleToServe = FixturePauseEventRemote.occurrence(meditationAt = now.minus(startedAgo))
        .copy(meditationAudioUrl = audioUrl),
    )
    val session = pauseSession(remote)
    session.start()
    val audio = MockGlobalPauseAudioPlayer()
    val snapshots = mutableListOf<GlobalPauseRewardSnapshot>()
    val visit = GlobalPauseVisit(
      session = session,
      audio = audio,
      scope = backgroundScope,
      snapshot = {
        if (snapshotDelay > Duration.ZERO) delay(snapshotDelay.toMillis())
        GlobalPauseRewardSnapshot.sample.also { snapshots += it }
      },
      receipt = { before ->
        val state = session.state.value
        RewardReceipt.pauseNight(
          before = before,
          awards = listOfNotNull(state.pauseAward, state.messageAward),
          gardenAfter = before.garden,
          heartBalanceAfter = before.heartBalance + (state.pauseAward?.hearts ?: 0),
          heartsEarnedTodayAfter = before.heartsEarnedToday,
          continuity = ContinuityTransition(7, 8),
          attendanceMissed = state.pauseAwardMissed,
          attendancePending = state.pauseAwardPending,
        )
      },
    )
    return Harness(remote, session, audio, visit, snapshots)
  }

  @Test
  @DisplayName("A member joining mid-sit joins the stream at the shared offset")
  fun joinsAtTheSharedOffset() = runTest {
    val h = harness(startedAgo = Duration.ofMinutes(5))

    h.visit.begin()
    assertEquals(GlobalPauseVisit.Phase.Meditating(Duration.ofMinutes(10)), h.visit.phase.value)
    assertEquals(listOf("https://x/meditation.mp3" to Duration.ofMinutes(5)), h.audio.played)
    assertTrue(h.session.isInSession)
  }

  @Test
  @DisplayName("A latecomer past the end goes straight to the reflection")
  fun latecomerSkipsToReflection() = runTest {
    // The meditation ended a minute ago, and the feedback phase is still open.
    val h = harness(startedAgo = Duration.ofMinutes(11))

    h.visit.begin()
    assertEquals(GlobalPauseVisit.Phase.Reflecting, h.visit.phase.value)
    assertTrue(h.audio.played.isEmpty())
  }

  @Test
  @DisplayName("The audio clock reaching the end opens the reflection")
  fun audioClockEndsIt() = runTest {
    val h = harness(startedAgo = Duration.ofMinutes(5))
    h.visit.begin()

    h.audio.advance(Duration.ofMinutes(10).minusMillis(400))
    advance(Duration.ofMillis(1))
    assertEquals(GlobalPauseVisit.Phase.Reflecting, h.visit.phase.value)
    // Frozen once, before the claim moved anything.
    assertEquals(1, h.snapshots.size)
  }

  @Test
  @DisplayName("With no audio at all, the wall clock still ends it")
  fun wallClockFallback() = runTest {
    val h = harness(startedAgo = Duration.ofMinutes(5), audioUrl = null)
    h.visit.begin()

    advance(Duration.ofMinutes(4))
    assertIs<GlobalPauseVisit.Phase.Meditating>(h.visit.phase.value)

    // The live window closes at five minutes, which ends it first.
    advance(Duration.ofMinutes(1).plusSeconds(1))
    assertEquals(GlobalPauseVisit.Phase.Reflecting, h.visit.phase.value)
  }

  @Test
  @DisplayName("The claim goes out as the reflection opens; presence leaves after its beat")
  fun claimThenHandback() = runTest {
    val h = harness(startedAgo = Duration.ofMinutes(5))
    h.visit.begin()
    advance(Duration.ofMillis(1))

    h.audio.advance(Duration.ofMinutes(10))
    advance(Duration.ofMillis(1))
    assertEquals(GlobalPauseVisit.Phase.Reflecting, h.visit.phase.value)
    assertEquals(1, h.remote.pauseClaimAttempts)
    // The closing beat is on the books before presence goes.
    assertEquals(listOf("beat:$PRESENCE_ID", "beat:$PRESENCE_ID"), h.remote.presenceLog)

    advance(GlobalPauseVisit.HANDBACK_DELAY)
    assertEquals("leave:$PRESENCE_ID", h.remote.presenceLog.last())
    assertEquals(1, h.audio.stopCount)
  }

  @Test
  @DisplayName("Books slow to freeze never let a heartbeat follow the leave")
  fun slowSnapshotLeavesNoGhost() = runTest {
    // Slower than the handback: the leave goes out before the claim does.
    val h = harness(startedAgo = Duration.ofMinutes(5), snapshotDelay = Duration.ofSeconds(3))
    h.visit.begin()
    advance(Duration.ofMillis(1))

    h.audio.advance(Duration.ofMinutes(10))
    advance(Duration.ofSeconds(10))
    assertEquals(GlobalPauseVisit.Phase.Reflecting, h.visit.phase.value)
    assertEquals("leave:$PRESENCE_ID", h.remote.presenceLog.last())
    // The claim still went out — it just sent no beat after the leave.
    assertEquals(1, h.remote.pauseClaimAttempts)

    h.visit.continueToRewards()
    assertIs<GlobalPauseVisit.Phase.Rewarding>(h.visit.phase.value)
  }

  @Test
  @DisplayName("The ritual opens on the settled award")
  fun ritualWaitsForTheAward() = runTest {
    val h = harness(startedAgo = Duration.ofMinutes(5))
    h.visit.begin()
    h.audio.advance(Duration.ofMinutes(10))
    advance(Duration.ofMillis(1))

    h.visit.continueToRewards()
    val rewarding = assertIs<GlobalPauseVisit.Phase.Rewarding>(h.visit.phase.value)
    assertEquals(5, rewarding.receipt.heartsAwarded)
    assertEquals(17, rewarding.receipt.heartBalanceAfter)

    h.visit.finish()
    assertEquals(GlobalPauseVisit.Phase.Finished, h.visit.phase.value)
  }

  @Test
  @DisplayName("Leaving mid-sit ends presence at once and claims nothing")
  fun leavingEarly() = runTest {
    val h = harness(startedAgo = Duration.ofMinutes(5))
    h.visit.begin()
    advance(Duration.ofMillis(1))

    h.visit.leave()
    advance(Duration.ofSeconds(1))
    assertEquals(GlobalPauseVisit.Phase.Finished, h.visit.phase.value)
    assertEquals("leave:$PRESENCE_ID", h.remote.presenceLog.last())
    assertEquals(0, h.remote.pauseClaimAttempts)

    // The triggers are gone with it: the end of the stream changes nothing.
    h.audio.advance(Duration.ofMinutes(10))
    advance(Duration.ofMinutes(10))
    assertEquals(GlobalPauseVisit.Phase.Finished, h.visit.phase.value)
    assertEquals(0, h.remote.pauseClaimAttempts)
  }
}
