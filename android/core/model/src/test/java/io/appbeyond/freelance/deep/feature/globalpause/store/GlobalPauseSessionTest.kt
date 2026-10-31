package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.feature.globalpause.model.GlobalPauseCardState
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseLiveSnapshot
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseSchedule
import io.appbeyond.freelance.deep.feature.globalpause.model.SyncedClock
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import java.time.Duration
import java.time.Instant
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The Global Pause engine, on virtual time. Ported from
 * Deep/DeepTests/GlobalPauseScheduleRolloverTests.swift and
 * GlobalPauseAwardTests.swift, plus the card's states, the presence cadence
 * and the lifecycle Android adds.
 */
class GlobalPauseSessionTest {

  /** An occurrence whose meditation starts [meditationIn] from [now]. */
  private fun TestScope.occurrence(
    meditationIn: Duration,
    nextIn: Duration? = null,
    lobbyAudioUrl: String? = null,
  ): PauseSchedule = FixturePauseEventRemote.occurrence(
    meditationAt = now.plus(meditationIn),
    nextMeditationAt = nextIn?.let { now.plus(it) },
    lobbyAudioUrl = lobbyAudioUrl,
  )

  /** Hands out scripted schedules (or failures); later calls repeat the last. */
  private class ScriptedRemote(
    private val script: List<Result<PauseSchedule>>,
    private val base: FixturePauseEventRemote = FixturePauseEventRemote(),
  ) : PauseEventRemote by base {
    var scheduleCalls = 0
      private set

    override suspend fun schedule(): PauseSchedule {
      val answer = script.getOrElse(scheduleCalls) { script.last() }
      scheduleCalls += 1
      return answer.getOrThrow()
    }
  }

  @Nested
  @DisplayName("When the occurrence in hand runs out")
  inner class Rollover {

    @Test
    @DisplayName("A spent occurrence is re-fetched at once, not a minute later")
    fun spentOccurrenceIsRefetchedImmediately() = runTest {
      val remote = ScriptedRemote(
        listOf(
          Result.success(occurrence(meditationIn = Duration.ofHours(-1))),
          Result.success(occurrence(meditationIn = Duration.ofMinutes(10), nextIn = Duration.ofHours(12))),
        ),
      )
      val session = pauseSession(remote)

      session.start()
      advanceUntil { remote.scheduleCalls >= 2 }

      assertEquals(2, remote.scheduleCalls)
      val target = assertNotNull(session.nextMeditationStart)
      assertTrue(target.isAfter(now))
    }

    @Test
    @DisplayName("A server still handing back the spent occurrence is not re-fetched in a loop")
    fun aStaleServerIsNotPolledInALoop() = runTest {
      val remote = ScriptedRemote(listOf(Result.success(occurrence(meditationIn = Duration.ofHours(-1)))))
      val session = pauseSession(remote)

      session.start()
      advance(Duration.ofSeconds(1))
      assertEquals(2, remote.scheduleCalls)

      // Then the 60s backoff, not a hammer.
      advance(Duration.ofSeconds(30))
      assertEquals(2, remote.scheduleCalls)
    }

    @Test
    @DisplayName("A failed re-fetch of a spent occurrence backs off rather than hammering")
    fun aFailedRefetchBacksOff() = runTest {
      val remote = ScriptedRemote(
        listOf(
          Result.success(occurrence(meditationIn = Duration.ofHours(-1))),
          Result.failure(java.io.IOException("offline")),
        ),
      )
      val session = pauseSession(remote)

      session.start()
      advance(Duration.ofSeconds(30))
      assertEquals(2, remote.scheduleCalls)
    }

    @Test
    @DisplayName("A current occurrence is not re-fetched")
    fun aCurrentOccurrenceIsLeftAlone() = runTest {
      val remote = ScriptedRemote(
        listOf(Result.success(occurrence(meditationIn = Duration.ofHours(1), nextIn = Duration.ofHours(12)))),
      )
      val session = pauseSession(remote)

      session.start()
      advance(Duration.ofSeconds(30))
      assertEquals(1, remote.scheduleCalls)
    }

    @Test
    @DisplayName("A meditation ending on the device's clock is confirmed with the server once")
    fun meditationEndIsConfirmedOnce() = runTest {
      val remote = ScriptedRemote(
        listOf(Result.success(occurrence(meditationIn = Duration.ofMinutes(-1), nextIn = Duration.ofHours(12)))),
      )
      val session = pauseSession(remote)

      session.start()
      assertTrue(session.state.value.isMeditationLive)
      advance(Duration.ofMinutes(8))
      assertEquals(1, remote.scheduleCalls, "Nothing to ask while the meditation runs.")

      advance(Duration.ofMinutes(1).plusSeconds(1))
      assertFalse(session.state.value.isMeditationLive)
      assertEquals(2, remote.scheduleCalls, "The end is confirmed at once, not when the feedback phase runs out.")

      advance(Duration.ofMinutes(5))
      assertEquals(2, remote.scheduleCalls, "Once — the feedback phase is not polled.")
    }

    @Test
    @DisplayName("The dev time-travel loop is followed on every wrap, not only the first")
    fun everyTimeTravelWrapIsFollowed() = runTest {
      val clock = SyncedClock(SchedulerClock(testScheduler))
      val schedule = occurrence(meditationIn = Duration.ZERO, nextIn = Duration.ofHours(12))
      val meditationStart = now
      // The server's loop: every schedule read lands 2s into the meditation.
      val remote = object : PauseEventRemote by FixturePauseEventRemote() {
        var scheduleCalls = 0
        override suspend fun schedule(): PauseSchedule {
          scheduleCalls += 1
          clock.sync(meditationStart.plusSeconds(2))
          return schedule
        }
      }
      val session = pauseSession(remote, clock = clock)

      session.start()
      repeat(3) { wrap ->
        assertTrue(session.state.value.isMeditationLive, "Live on pass ${wrap + 1}")
        advance(Duration.ofMinutes(10))
        assertTrue(session.state.value.isMeditationLive, "Back on LIVE after wrap ${wrap + 1}")
        assertEquals(GlobalPauseCardState.Live, session.state.value.cardState)
      }
      assertEquals(4, remote.scheduleCalls)
    }

    @Test
    @DisplayName("No schedule at all retries a minute later")
    fun noScheduleRetries() = runTest {
      val remote = ScriptedRemote(listOf(Result.failure(java.io.IOException("offline"))))
      val session = pauseSession(remote)

      session.start()
      assertEquals(GlobalPauseCardState.Off(null), session.state.value.cardState)
      advance(Duration.ofSeconds(59))
      assertEquals(1, remote.scheduleCalls)
      advance(Duration.ofSeconds(2))
      assertEquals(2, remote.scheduleCalls)
    }
  }

  @Nested
  @DisplayName("The card")
  inner class Card {

    @Test
    @DisplayName("At rest it names the next meditation")
    fun restsOnTheNextMeditation() = runTest {
      val remote = FixturePauseEventRemote(scheduleToServe = occurrence(meditationIn = Duration.ofHours(2)))
      val session = pauseSession(remote)

      session.start()
      assertEquals(GlobalPauseCardState.Off(now.plus(Duration.ofHours(2))), session.state.value.cardState)
      assertFalse(session.state.value.isMeditationLive)
    }

    @Test
    @DisplayName("It counts down through the final fifteen minutes, then goes live on the stroke")
    fun countsDownThenGoesLive() = runTest {
      val start = now.plus(Duration.ofMinutes(20))
      val remote = FixturePauseEventRemote(scheduleToServe = occurrence(meditationIn = Duration.ofMinutes(20)))
      val session = pauseSession(remote)

      session.start()
      assertEquals(GlobalPauseCardState.Off(start), session.state.value.cardState)

      // The countdown opens exactly fifteen minutes out.
      advance(Duration.ofMinutes(5))
      assertEquals(GlobalPauseCardState.Countdown(start), session.state.value.cardState)

      advance(Duration.ofMinutes(15))
      assertEquals(GlobalPauseCardState.Live, session.state.value.cardState)
      assertTrue(session.state.value.isMeditationLive)
      assertEquals(Duration.ZERO, session.meditationElapsed)

      // Ten minutes later the window closes, and the card names tomorrow.
      advance(Duration.ofMinutes(10))
      assertFalse(session.state.value.isMeditationLive)
      assertIs<GlobalPauseCardState.Off>(session.state.value.cardState)
    }

    @Test
    @DisplayName("A latecomer reads the shared offset, not zero")
    fun meditationElapsedIsShared() = runTest {
      val remote = FixturePauseEventRemote(scheduleToServe = occurrence(meditationIn = Duration.ofMinutes(-3)))
      val session = pauseSession(remote)

      session.start()
      assertEquals(Duration.ofMinutes(3), session.meditationElapsed)
      assertEquals(Duration.ofMinutes(10), session.meditationDuration)
    }

    @Test
    @DisplayName("ON AIR burns for exactly the set's minutes")
    fun fukuOnAirFollowsTheSet() = runTest {
      // The lobby opens in a minute; the set is a 10s intro then 262s of track.
      val remote = FixturePauseEventRemote(
        scheduleToServe = occurrence(meditationIn = Duration.ofMinutes(11), lobbyAudioUrl = "https://x/lounge.mp3"),
      )
      val session = pauseSession(remote, introDuration = Duration.ofSeconds(10))

      session.start()
      assertFalse(session.state.value.isFukuOnAir)

      advance(Duration.ofMinutes(1))
      assertTrue(session.state.value.isFukuOnAir)

      advance(Duration.ofSeconds(272))
      assertFalse(session.state.value.isFukuOnAir)
    }

    @Test
    @DisplayName("the lounge track's live offset runs only through the music")
    fun loungeElapsedFollowsTheMusic() = runTest {
      // The lobby opens in a minute; the set is a 10s intro then 262s of track.
      val remote = FixturePauseEventRemote(
        scheduleToServe = occurrence(meditationIn = Duration.ofMinutes(11), lobbyAudioUrl = "https://x/lounge.mp3"),
      )
      val session = pauseSession(remote, introDuration = Duration.ofSeconds(10))

      session.start()
      assertNull(session.loungeElapsed, "nothing to join before the set opens")

      advance(Duration.ofSeconds(65))
      assertNull(session.loungeElapsed, "Fuku is still talking — the track waits its turn")

      advance(Duration.ofSeconds(65))
      // 130s past the stroke, less the 10s intro: everyone hears the same bar.
      assertEquals(Duration.ofSeconds(60), session.loungeElapsed)

      advance(Duration.ofSeconds(202))
      assertNull(session.loungeElapsed, "the set has signed off; a radio rejoining now stops")
    }

    @Test
    @DisplayName("no lounge track, no offset to join")
    fun loungeElapsedNeedsATrack() = runTest {
      val remote = FixturePauseEventRemote(scheduleToServe = occurrence(meditationIn = Duration.ofMinutes(11)))
      val session = pauseSession(remote, introDuration = Duration.ofSeconds(10))

      session.start()
      advance(Duration.ofSeconds(130))
      assertNull(session.loungeElapsed)
    }
  }

  @Nested
  @DisplayName("Presence")
  inner class Presence {

    @Test
    @DisplayName("Presence renews every 10s and the room is read every 5s")
    fun cadence() = runTest {
      val remote = FixturePauseEventRemote(scheduleToServe = occurrence(meditationIn = Duration.ZERO))
      val session = pauseSession(remote)

      session.start()
      session.enterSession()
      advance(Duration.ofMillis(1))
      assertEquals(1, remote.presenceLog.count { it.startsWith("beat:") })
      assertEquals(1, remote.liveCalls)

      advance(Duration.ofSeconds(25))
      assertEquals(3, remote.presenceLog.count { it.startsWith("beat:") }) // 0, 10, 20
      assertEquals(6, remote.liveCalls) // 0, 5, 10, 15, 20, 25
      assertEquals(4200, session.state.value.participantCount)
      assertEquals(listOf("AS", "EU", "NA", "SA", "AF", "OC").toSet(), session.state.value.participantsByContinent.keys)
    }

    @Test
    @DisplayName("Entering twice never doubles the loops")
    fun enterIsIdempotent() = runTest {
      val remote = FixturePauseEventRemote(scheduleToServe = occurrence(meditationIn = Duration.ZERO))
      val session = pauseSession(remote)

      session.enterSession()
      session.enterSession()
      advance(Duration.ofSeconds(15))
      assertEquals(2, remote.presenceLog.count { it.startsWith("beat:") })
    }

    @Test
    @DisplayName("Leaving stops the beats and tells the server")
    fun leaveSendsDelete() = runTest {
      val remote = FixturePauseEventRemote(scheduleToServe = occurrence(meditationIn = Duration.ZERO))
      val session = pauseSession(remote)

      session.enterSession()
      advance(Duration.ofSeconds(1))
      session.leaveSession()
      advance(Duration.ofSeconds(30))

      assertEquals(listOf("beat:$PRESENCE_ID", "leave:$PRESENCE_ID"), remote.presenceLog)
      assertNull(session.state.value.myLocation)
      assertFalse(session.isInSession)
    }

    @Test
    @DisplayName("In the background the beats go on, but the room's poll rests")
    fun backgroundParksThePoll() = runTest {
      val remote = FixturePauseEventRemote(scheduleToServe = occurrence(meditationIn = Duration.ZERO))
      val session = pauseSession(remote)

      session.start()
      session.enterSession()
      advance(Duration.ofMillis(1))
      session.onBackground()
      val polls = remote.liveCalls
      val schedules = remote.scheduleCalls

      advance(Duration.ofSeconds(30))
      assertEquals(polls, remote.liveCalls)
      assertEquals(4, remote.presenceLog.count { it.startsWith("beat:") }) // 0, 10, 20, 30

      // Back: the poll resumes at once, and the schedule (and clock) re-sync.
      session.onForeground()
      advance(Duration.ofMillis(1))
      assertEquals(polls + 1, remote.liveCalls)
      assertEquals(schedules + 1, remote.scheduleCalls)
    }

    @Test
    @DisplayName("The heartbeat's location becomes the member's own")
    fun heartbeatResolvesHome() = runTest {
      val remote = FixturePauseEventRemote(scheduleToServe = occurrence(meditationIn = Duration.ZERO))
      val session = pauseSession(remote)

      session.enterSession()
      advance(Duration.ofMillis(1))
      assertEquals(PauseJoinPoint(13.8f, 100.5f), session.state.value.myLocation)
    }

    @Test
    @DisplayName("The member's own join sparks once, from the screen — its echo is swallowed")
    fun ownJoinIsSwallowed() = runTest {
      val base = FixturePauseEventRemote(scheduleToServe = occurrence(meditationIn = Duration.ZERO))
      // A real server stamps each join once, so every poll repeats them as-is.
      val mine = PauseLiveSnapshot.Join("TH", now, 13.8f, 100.5f)
      val stranger = PauseLiveSnapshot.Join("JP", now, 35.0f, 135.8f)
      val remote = object : PauseEventRemote by base {
        override suspend fun live(): PauseLiveSnapshot =
          base.live().copy(recentJoins = listOf(mine, stranger))
      }
      val session = pauseSession(remote)
      val sparks = mutableListOf<PauseJoinPoint>()
      backgroundScope.launch { session.joins.collect { sparks += it } }

      session.enterSession()
      advance(Duration.ofSeconds(12))

      // Kyoto sparks once; Bangkok — the member's own echo — never does, and
      // later polls replay neither.
      assertEquals(listOf(PauseJoinPoint(35.0f, 135.8f)), sparks)
    }
  }

  @Nested
  @DisplayName("The night's award")
  inner class Awards {

    private fun TestScope.liveRemote() =
      FixturePauseEventRemote(scheduleToServe = occurrence(meditationIn = Duration.ofMinutes(-5)))

    @Test
    @DisplayName("A settled claim survives the reflection handback's leaveSession")
    fun awardSurvivesLeaveSession() = runTest {
      val sunk = mutableListOf<io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant>()
      val session = pauseSession(liveRemote(), awardSink = { sunk += it })

      session.enterSession()
      session.claimPauseAward()
      advanceUntil { session.state.value.pauseAward != null }

      assertEquals(5, session.state.value.pauseAward?.hearts)
      assertEquals(5, session.state.value.pauseAward?.sunlight)
      assertEquals(1, sunk.size)

      session.leaveSession()
      assertNotNull(session.state.value.pauseAward)
    }

    @Test
    @DisplayName("The claim's closing heartbeat goes out before the claim")
    fun finalBeatFirst() = runTest {
      val remote = liveRemote()
      val session = pauseSession(remote)

      session.claimPauseAward()
      advanceUntil { session.state.value.pauseAward != null }
      assertEquals(listOf("beat:$PRESENCE_ID"), remote.presenceLog)
      assertEquals(1, remote.pauseClaimAttempts)
    }

    @Test
    @DisplayName("No heartbeat follows the claim's closing beat")
    fun noBeatAfterTheClaim() = runTest {
      val remote = liveRemote()
      val session = pauseSession(remote)

      session.enterSession()
      advance(Duration.ofSeconds(9))
      assertEquals(1, remote.presenceLog.count { it.startsWith("beat:") })

      session.claimPauseAward()
      advanceUntil { session.state.value.pauseAward != null }
      assertEquals(2, remote.presenceLog.count { it.startsWith("beat:") }, "The closing beat…")

      // Past the loop's next 10s tick, and the one after.
      advance(Duration.ofSeconds(25))
      assertEquals(2, remote.presenceLog.count { it.startsWith("beat:") }, "…is the last one.")
      assertTrue(session.isInSession, "Still in session until the visit leaves.")

      session.leaveSession()
      advance(Duration.ofMillis(1))
      assertEquals("leave:$PRESENCE_ID", remote.presenceLog.last())
    }

    @Test
    @DisplayName("A closing beat still in flight lands before the leave goes out")
    fun leaveWaitsForTheClosingBeat() = runTest {
      val remote = liveRemote().apply { heartbeatDelay = Duration.ofSeconds(2) }
      val session = pauseSession(remote)

      session.enterSession()
      advance(Duration.ofSeconds(3))
      session.claimPauseAward()
      // The handback, while the closing beat is still on the wire.
      session.leaveSession()
      advance(Duration.ofSeconds(10))

      assertEquals(
        listOf("beat:$PRESENCE_ID", "beat:$PRESENCE_ID", "leave:$PRESENCE_ID"),
        remote.presenceLog,
      )
    }

    @Test
    @DisplayName("A claim made after the leave sends no beat to bring presence back")
    fun claimAfterLeaveSendsNoBeat() = runTest {
      val remote = liveRemote()
      val session = pauseSession(remote)

      session.enterSession()
      advance(Duration.ofMillis(1))
      session.leaveSession()
      session.claimPauseAward()
      advanceUntil { session.state.value.pauseAward != null }

      assertEquals(listOf("beat:$PRESENCE_ID", "leave:$PRESENCE_ID"), remote.presenceLog)
      assertEquals(1, remote.pauseClaimAttempts)
    }

    @Test
    @DisplayName("A claim still out when the member signs out lands on nobody's books")
    fun claimOutlivingItsMemberIsDropped() = runTest {
      val remote = liveRemote().apply { pauseClaimDelay = Duration.ofSeconds(3) }
      var awards = 0
      var attendances = 0
      val session = pauseSession(remote, awardSink = { awards += 1 }, activitySink = { attendances += 1 })

      session.enterSession()
      session.claimPauseAward()
      advance(Duration.ofSeconds(1))
      session.leaveSession()
      // Signed out — and someone else signed in — while the reply is delayed.
      session.forgetAccount()
      advance(Duration.ofSeconds(10))

      assertEquals(0, awards)
      assertEquals(0, attendances)
      assertNull(session.state.value.pauseAward)
      assertFalse(session.state.value.pauseAwardPending)
    }

    @Test
    @DisplayName("A sign-out while the attendance is being recorded stops the award from publishing")
    fun signOutMidPublicationPublishesNothing() = runTest {
      var recording = false
      var awards = 0
      // The journal's persist, which the sign-out can't interrupt.
      val session = pauseSession(
        liveRemote(),
        awardSink = { awards += 1 },
        activitySink = {
          recording = true
          withContext(NonCancellable) { delay(2_000) }
        },
      )

      session.enterSession()
      session.claimPauseAward()
      advanceUntil { recording }
      session.forgetAccount()
      advance(Duration.ofSeconds(10))

      assertEquals(0, awards)
      assertNull(session.state.value.pauseAward)
    }

    @Test
    @DisplayName("A leave held behind a slow beat never deletes a rejoin's fresh presence")
    fun rejoinCancelsAStaleLeave() = runTest {
      val remote = liveRemote().apply { heartbeatDelay = Duration.ofSeconds(2) }
      val session = pauseSession(remote)

      session.enterSession()
      advance(Duration.ofSeconds(3))
      session.claimPauseAward()
      // The leave waits on the closing beat — and the member is back first.
      session.leaveSession()
      session.enterSession()
      advance(Duration.ofSeconds(10))

      assertFalse(remote.presenceLog.contains("leave:$PRESENCE_ID"))
      assertEquals("beat:$PRESENCE_ID", remote.presenceLog.last())
      assertTrue(session.isInSession)
      session.leaveSession()
    }

    @Test
    @DisplayName("The next session visit starts without last night's award")
    fun nextVisitStartsClean() = runTest {
      val session = pauseSession(liveRemote())

      session.enterSession()
      session.claimPauseAward()
      advanceUntil { session.state.value.pauseAward != null }
      session.leaveSession()

      session.enterSession()
      assertNull(session.state.value.pauseAward)
      session.leaveSession()
    }

    @Test
    @DisplayName("A claim landing after leaveSession still reaches the caption and sink")
    fun lateClaimStillLands() = runTest {
      var sunk = 0
      val session = pauseSession(liveRemote(), awardSink = { sunk += 1 })

      session.enterSession()
      session.claimPauseAward()
      session.leaveSession()

      advanceUntil { session.state.value.pauseAward != null }
      assertEquals(5, session.state.value.pauseAward?.hearts)
      assertEquals(1, sunk)
    }

    @Test
    @DisplayName("Waiting for a claim returns once it settles")
    fun settleWaitsForTheClaim() = runTest {
      val session = pauseSession(liveRemote())

      session.enterSession()
      session.claimPauseAward()
      session.settlePauseAward()

      assertEquals(5, session.state.value.pauseAward?.hearts)
      session.leaveSession()
    }

    @Test
    @DisplayName("Waiting when nothing is in flight returns at once")
    fun settleReturnsWithoutAClaim() = runTest {
      val session = pauseSession(liveRemote())
      session.settlePauseAward()
      assertNull(session.state.value.pauseAward)
    }

    @Test
    @DisplayName("The night's first peace message is kept for the ritual's total")
    fun firstMessageAwardIsKept() = runTest {
      val session = pauseSession(liveRemote())
      session.enterSession()

      session.post("Peace to you all", "peace")
      assertEquals(1, session.state.value.messageAward?.hearts)
      assertEquals(1, session.state.value.messageAward?.sunlight)
      assertNotNull(session.state.value.postedMessage)

      // Later messages come back bare — the first award stays the night's truth.
      session.post("And again", null)
      assertEquals(1, session.state.value.messageAward?.hearts)
      session.leaveSession()
    }

    @Test
    @DisplayName("A claim lost to the network is retried until it lands")
    fun transportFailuresRetryThenLand() = runTest {
      val remote = liveRemote().apply { pauseClaimFailures = 2 }
      var sunk = 0
      val session = pauseSession(remote, awardSink = { sunk += 1 })

      session.enterSession()
      session.claimPauseAward()
      advanceUntil { session.state.value.pauseAward != null }

      assertEquals(5, session.state.value.pauseAward?.hearts)
      assertEquals(3, remote.pauseClaimAttempts)
      assertEquals(1, sunk)
      session.leaveSession()
    }

    @Test
    @DisplayName("The retry gives up after its last attempt")
    fun retryIsBounded() = runTest {
      val remote = liveRemote().apply { pauseClaimFailures = 10 }
      val session = pauseSession(remote)

      session.enterSession()
      session.claimPauseAward()
      session.settlePauseAward(Duration.ofSeconds(2))

      assertEquals(4, remote.pauseClaimAttempts)
      assertNull(session.state.value.pauseAward)
      assertFalse(session.state.value.pauseAwardMissed)
      // No answer ever came: the night's outcome is unknown, not "full".
      assertTrue(session.state.value.pauseAwardPending)
      session.leaveSession()

      session.enterSession()
      assertFalse(session.state.value.pauseAwardPending)
      session.leaveSession()
    }

    @Test
    @DisplayName("A claim still unanswered when the ending composes is pending, then lands")
    fun slowClaimIsPendingThenLands() = runTest {
      val remote = liveRemote().apply { pauseClaimDelay = Duration.ofMillis(400) }
      var sunk = 0
      val session = pauseSession(remote, awardSink = { sunk += 1 })

      session.enterSession()
      session.claimPauseAward()
      session.settlePauseAward(Duration.ofMillis(50))
      assertTrue(session.state.value.pauseAwardPending)
      assertNull(session.state.value.pauseAward)
      assertFalse(session.state.value.pauseAwardMissed)

      advanceUntil { session.state.value.pauseAward != null }
      assertEquals(5, session.state.value.pauseAward?.hearts)
      assertFalse(session.state.value.pauseAwardPending)
      assertEquals(1, sunk)
      session.leaveSession()
    }

    @Test
    @DisplayName("An answered claim is never pending")
    fun answeredClaimIsNotPending() = runTest {
      val remote = liveRemote().apply { pauseEligible = false }
      val session = pauseSession(remote)

      session.enterSession()
      session.claimPauseAward()
      assertTrue(session.state.value.pauseAwardPending)
      session.settlePauseAward()

      assertFalse(session.state.value.pauseAwardPending)
      assertTrue(session.state.value.pauseAwardMissed)
      session.leaveSession()
    }

    @Test
    @DisplayName("An expired session is an answer, not a blip — no retry")
    fun unauthorizedIsNotRetried() = runTest {
      val remote = liveRemote().apply {
        pauseClaimFailures = 1
        pauseClaimError = IllegalStateException("401 unauthorized")
      }
      val session = pauseSession(remote)

      session.enterSession()
      session.claimPauseAward()
      session.settlePauseAward()

      assertEquals(1, remote.pauseClaimAttempts)
      assertNull(session.state.value.pauseAward)
      session.leaveSession()
    }

    @Test
    @DisplayName("An ineligible night is marked missed and keeps no day")
    fun ineligibleNightIsMissed() = runTest {
      val remote = liveRemote().apply { pauseEligible = false }
      var sunk = 0
      val days = mutableListOf<Instant>()
      val session = pauseSession(remote, awardSink = { sunk += 1 }, activitySink = { days += it })

      session.enterSession()
      session.claimPauseAward()
      session.settlePauseAward()

      assertTrue(session.state.value.pauseAwardMissed)
      assertNull(session.state.value.pauseAward)
      assertEquals(0, sunk)
      assertTrue(days.isEmpty())

      // Like the award, it survives the reflection handback…
      session.leaveSession()
      assertTrue(session.state.value.pauseAwardMissed)

      // …and is forgotten as the next visit begins.
      session.enterSession()
      assertFalse(session.state.value.pauseAwardMissed)
      session.leaveSession()
    }

    @Test
    @DisplayName("A counted night keeps the day in the rhythm")
    fun eligibleNightRecordsActivity() = runTest {
      val days = mutableListOf<Instant>()
      val session = pauseSession(liveRemote(), activitySink = { days += it })

      session.enterSession()
      session.claimPauseAward()
      advanceUntil { session.state.value.pauseAward != null }

      assertEquals(1, days.size)
      assertFalse(session.state.value.pauseAwardMissed)
      session.leaveSession()
    }

    @Test
    @DisplayName("A night already claimed still counts, with no fresh grant")
    fun alreadyClaimedNightStillCounts() = runTest {
      val days = mutableListOf<Instant>()
      val session = pauseSession(liveRemote(), activitySink = { days += it })

      session.enterSession()
      session.claimPauseAward()
      advanceUntil { session.state.value.pauseAward != null }
      session.leaveSession()

      session.enterSession()
      session.claimPauseAward()
      session.settlePauseAward()

      assertNull(session.state.value.pauseAward)
      assertFalse(session.state.value.pauseAwardMissed)
      assertEquals(2, days.size)
      session.leaveSession()
    }

    @Test
    @DisplayName("The next session visit starts without last night's message award")
    fun nextVisitForgetsTheMessageAward() = runTest {
      val session = pauseSession(liveRemote())
      session.enterSession()
      session.post("Peace to you all", "peace")
      assertNotNull(session.state.value.messageAward)
      session.leaveSession()

      session.enterSession()
      assertNull(session.state.value.messageAward)
      session.leaveSession()
    }
  }
}
