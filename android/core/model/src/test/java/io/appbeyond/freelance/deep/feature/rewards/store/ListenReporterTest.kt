package io.appbeyond.freelance.deep.feature.rewards.store

import io.appbeyond.freelance.deep.auth.HttpStatusCarrying
import io.appbeyond.freelance.deep.auth.TransportFailure
import io.appbeyond.freelance.deep.feature.rewards.model.AwardCap
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.feature.rewards.model.ListenOutcome
import io.appbeyond.freelance.deep.feature.rewards.model.ListenTally
import io.appbeyond.freelance.deep.feature.rewards.model.RewardRules
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.yield
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.Locale
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** A 4xx or 5xx, as the app's `DeepApiException.Http` carries it. */
private class HttpFailure(override val status: Int) : Exception("HTTP $status"), HttpStatusCarrying

/** Offline, as the app's `DeepApiException.Transport`. */
private class Offline : Exception("offline"), TransportFailure

/** A scripted `/me/sound/listens`: answers in order, then grants by default. */
private class ListenServer {
  val replies = ArrayDeque<Any>()

  /** Yield a few times mid-request, so overlapping flushes would interleave. */
  var suspends = false

  /** Parks every request until completed — a slow network. */
  var gate: CompletableDeferred<Unit>? = null

  val calls = mutableListOf<Pair<String, Instant>>()
  var maxInFlight = 0
  private var inFlight = 0

  suspend fun report(trackId: String, completedAt: Instant): ListenOutcome {
    calls += trackId to completedAt
    inFlight++
    maxInFlight = maxOf(maxInFlight, inFlight)
    try {
      if (suspends) repeat(5) { yield() }
      gate?.await()
      return when (val reply = replies.removeFirstOrNull() ?: granted(earned = 1)) {
        is ListenOutcome -> reply
        is Exception -> throw reply
        else -> error("Unknown reply $reply")
      }
    } finally {
      inFlight--
    }
  }
}

/** A hand-cranked clock. */
private class TestClock(var now: Instant) : Clock() {
  override fun instant(): Instant = now
  override fun getZone(): ZoneId = ZoneOffset.UTC
  override fun withZone(zone: ZoneId?): Clock = this
}

private fun granted(earned: Int, perDay: Int = 3) = ListenOutcome(
  judged = true,
  granted = true,
  tally = ListenTally(dayKey = "2027-01-15", earned = earned, perDay = perDay),
  grant = AwardGrant(hearts = 1, sunlight = 1),
)

private fun capped(reason: AwardCap, earned: Int, perDay: Int = 3) = ListenOutcome(
  judged = true,
  granted = false,
  cappedBy = reason,
  tally = ListenTally(dayKey = "2027-01-15", earned = earned, perDay = perDay),
  grant = AwardGrant(heartsBalance = 100),
)

/** Everything one reporter talks to, kept so tests can look. */
private class Rig(
  val reporter: ListenReporter,
  val server: ListenServer,
  val clock: TestClock,
  val queueBlob: InMemoryBlobStore,
  val stampBlob: InMemoryBlobStore,
  val activities: MutableList<Instant>,
  val grants: MutableList<AwardGrant>,
)

/**
 * The durable listen report behind sound hearts. Ported from
 * Deep/DeepTests/ListenReporterTests.swift; a second reporter over the same
 * blobs stands in for a relaunch on the same `UserDefaults` suite.
 *
 * The regressions it guards: a report was fire-and-forget, so any network
 * blip silently cost the heart; and a correct heart arrived with no word at
 * all, so the rules read as random.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ListenReporterTest {
  /** 2027-01-15 08:00 UTC — mid-morning, so an hour either way is the same day. */
  private val morning: Instant = Instant.ofEpochSecond(1_800_000_000)

  private fun TestScope.rig(
    server: ListenServer = ListenServer(),
    clock: TestClock = TestClock(morning),
    queueBlob: InMemoryBlobStore = InMemoryBlobStore(),
    stampBlob: InMemoryBlobStore = InMemoryBlobStore(),
    noticeDuration: Duration = Duration.ofHours(1),
  ): Rig {
    val activities = mutableListOf<Instant>()
    val grants = mutableListOf<AwardGrant>()
    val reporter = ListenReporter(
      report = server::report,
      recordActivity = { activities += it },
      queueBlob = queueBlob,
      stampBlob = stampBlob,
      scope = backgroundScope,
      clock = clock,
      zone = ZoneOffset.UTC,
      // Long enough that no notice expires mid-test; tests step through a
      // sequence with `advanceNotice()`.
      noticeDuration = noticeDuration,
    )
    reporter.awardSink = { grants += it }
    return Rig(reporter, server, clock, queueBlob, stampBlob, activities, grants)
  }

  /** A fresh reporter over [previous]'s disk and server — a relaunch. */
  private fun TestScope.relaunch(previous: Rig): Rig =
    rig(previous.server, previous.clock, previous.queueBlob, previous.stampBlob)

  // MARK: - Queue

  @Test
  @DisplayName("A listen lost to the network is kept, survives a relaunch, and lands on retry")
  fun persistsAndRetries() = runTest {
    val rig = rig()
    rig.server.replies += Offline()

    rig.reporter.record("rain", morning)
    rig.reporter.flush()
    assertTrue(rig.reporter.hasPending)
    assertTrue(rig.grants.isEmpty())

    // A relaunch reads the same queue back and delivers it, finish time intact.
    val relaunched = relaunch(rig)
    relaunched.reporter.restore()
    assertTrue(relaunched.reporter.hasPending)
    relaunched.reporter.flush()

    assertFalse(relaunched.reporter.hasPending)
    assertEquals(1, relaunched.grants.size)
    assertEquals(2, rig.server.calls.size)
    assertEquals("rain" to morning, rig.server.calls.last())
  }

  @Test
  @DisplayName("A 5xx or an expired session keeps the listen for later")
  fun serverAndAuthFailuresKeep() = runTest {
    val rig = rig()
    rig.server.replies += HttpFailure(503)
    rig.server.replies += HttpFailure(401)

    rig.reporter.record("rain", morning)
    rig.reporter.flush()
    assertTrue(rig.reporter.hasPending)

    rig.reporter.flush()
    assertTrue(rig.reporter.hasPending)

    rig.reporter.flush()
    assertFalse(rig.reporter.hasPending)
    assertEquals(3, rig.server.calls.size)
  }

  @Test
  @DisplayName("A track the server no longer has is dropped, not retried forever")
  fun notFoundDrops() = runTest {
    val rig = rig()
    rig.server.replies += HttpFailure(404)

    rig.reporter.record("gone", morning)
    rig.reporter.flush()

    assertFalse(rig.reporter.hasPending)
    assertNull(rig.reporter.notice.value)
    rig.reporter.flush()
    assertEquals(1, rig.server.calls.size)
  }

  @Test
  @DisplayName("A locked DEEP Premium track is dropped, and never holds up the listens behind it")
  fun premiumLockedDropsWithoutBlocking() = runTest {
    val rig = rig()
    rig.server.replies += HttpFailure(403)

    rig.reporter.record("locked", morning)
    rig.reporter.record("rain", morning)
    rig.reporter.flush()

    assertFalse(rig.reporter.hasPending)
    assertEquals(listOf("locked", "rain"), rig.server.calls.map { it.first })
    assertEquals(1, rig.grants.size)
  }

  @Test
  @DisplayName("A listen the server declines to place (stale) is dropped silently")
  fun staleDrops() = runTest {
    val rig = rig()
    rig.server.replies += ListenOutcome.Unjudged

    rig.reporter.record("rain", morning)
    rig.reporter.flush()

    assertFalse(rig.reporter.hasPending)
    assertNull(rig.reporter.notice.value)
  }

  @Test
  @DisplayName("Listens older than 48h are pruned without a request")
  fun prunesAfterRetention() = runTest {
    val rig = rig()
    rig.server.replies += Offline()

    rig.reporter.record("rain", morning)
    rig.reporter.flush()
    assertTrue(rig.reporter.hasPending)

    rig.clock.now = morning.plus(Duration.ofHours(49))
    assertFalse(rig.reporter.hasPending)
    rig.reporter.flush()

    assertTrue(rig.reporter.queued.isEmpty())
    assertNull(rig.queueBlob.value, "The pruned queue is gone from disk too.")
    assertEquals(1, rig.server.calls.size)
  }

  @Test
  @DisplayName("The same track finished twice in a day is queued once; a new day queues again")
  fun dedupesPerTrackPerDay() = runTest {
    val rig = rig()
    repeat(10) { rig.server.replies += Offline() }

    rig.reporter.record("rain", morning)
    rig.reporter.record("rain", morning.plus(Duration.ofHours(1)))
    rig.reporter.record("waves", morning.plus(Duration.ofHours(2)))
    rig.reporter.record("rain", morning.plus(Duration.ofHours(24)))
    rig.reporter.flush()

    assertEquals(listOf("rain", "waves", "rain"), rig.reporter.queued.map { it.trackId })
  }

  @Test
  @DisplayName("A Thai device's Buddhist calendar dedupes and stamps by the same days")
  fun buddhistCalendarDays() = runTest {
    val original = Locale.getDefault()
    try {
      Locale.setDefault(Locale.forLanguageTag("th-TH-u-ca-buddhist"))
      val rig = rig()
      repeat(10) { rig.server.replies += Offline() }

      rig.reporter.record("rain", morning)
      rig.reporter.record("rain", morning.plus(Duration.ofHours(1)))
      rig.reporter.record("rain", morning.plus(Duration.ofHours(24)))
      rig.reporter.flush()
      assertEquals(2, rig.reporter.queued.size)

      // Today's-hearts-are-in is said once a day, as on any calendar.
      rig.clock.now = morning.plus(Duration.ofHours(24))
      rig.reporter.reset()
      rig.server.replies.clear()
      rig.server.replies += capped(AwardCap.KIND_CAP, earned = 3)
      rig.server.replies += capped(AwardCap.KIND_CAP, earned = 3)
      rig.reporter.record("waves", rig.clock.now)
      rig.reporter.flush()
      assertEquals(ListenNotice.Kind.DayComplete(3), rig.reporter.notice.value?.kind)
      rig.reporter.advanceNotice()
      rig.reporter.record("wind", rig.clock.now)
      rig.reporter.flush()
      assertNull(rig.reporter.notice.value)
    } finally {
      Locale.setDefault(original)
    }
  }

  @Test
  @DisplayName("A notice's haptic is claimed once, however many surfaces show it")
  fun hapticClaimedOnce() = runTest {
    val rig = rig()

    rig.reporter.record("rain", morning)
    rig.reporter.flush()
    val first = checkNotNull(rig.reporter.notice.value)

    // Now Playing and the mini player both see the same notice.
    assertTrue(rig.reporter.claimHaptic(first))
    assertFalse(rig.reporter.claimHaptic(first))

    // The next heart is its own moment.
    rig.reporter.advanceNotice()
    rig.reporter.record("waves", morning)
    rig.reporter.flush()
    val second = checkNotNull(rig.reporter.notice.value)
    assertTrue(rig.reporter.claimHaptic(second))
  }

  @Test
  @DisplayName("A finished track keeps the day, at the moment it finished — offline too")
  fun recordsTrackActivity() = runTest {
    val rig = rig()
    rig.server.replies += Offline()
    val finishedAt = morning.minusSeconds(90)

    rig.reporter.record("rain", finishedAt)
    rig.reporter.flush()

    assertEquals(listOf(finishedAt), rig.activities)
  }

  @Test
  @DisplayName("Flushes never overlap: each listen is sent once, one request at a time")
  fun flushIsSerial() = runTest {
    val rig = rig()
    rig.server.suspends = true

    rig.reporter.record("rain", morning)
    rig.reporter.record("waves", morning)
    rig.reporter.record("wind", morning)
    val first = async { rig.reporter.flush() }
    val second = async { rig.reporter.flush() }
    first.await()
    second.await()

    assertEquals(1, rig.server.maxInFlight)
    assertEquals(listOf("rain", "waves", "wind"), rig.server.calls.map { it.first })
    assertFalse(rig.reporter.hasPending)
  }

  @Test
  @DisplayName("A listen recorded mid-flush goes out on the same flush")
  fun recordMidFlushIsSent() = runTest {
    val rig = rig()
    val gate = CompletableDeferred<Unit>()
    rig.server.gate = gate

    rig.reporter.record("rain", morning)
    runCurrent()
    rig.reporter.record("waves", morning)
    gate.complete(Unit)
    rig.reporter.flush()

    assertEquals(listOf("rain", "waves"), rig.server.calls.map { it.first })
    assertFalse(rig.reporter.hasPending)
  }

  @Test
  @DisplayName("A track ending as the member logs out is never queued for the next account")
  fun resetWhileRecordingDropsTheListen() = runTest {
    val activityGate = CompletableDeferred<Unit>()
    val server = ListenServer()
    val queueBlob = InMemoryBlobStore()
    val reporter = ListenReporter(
      report = server::report,
      // The journal's disk write, still in flight when the log out lands.
      recordActivity = { activityGate.await() },
      queueBlob = queueBlob,
      stampBlob = InMemoryBlobStore(),
      scope = backgroundScope,
      clock = TestClock(morning),
      zone = ZoneOffset.UTC,
    )
    reporter.restore()

    val recording = launch { reporter.record("rain", morning) }
    runCurrent()
    reporter.reset()
    activityGate.complete(Unit)
    recording.join()
    reporter.flush()

    assertTrue(reporter.queued.isEmpty())
    assertNull(queueBlob.value, "Nothing reaches the disk the next account reads.")
    assertTrue(server.calls.isEmpty(), "Nothing is reported under the next account's token.")
  }

  @Test
  @DisplayName("A reset mid-request drops the signed-out account's answer")
  fun resetDropsInFlightAnswer() = runTest {
    val rig = rig()
    val gate = CompletableDeferred<Unit>()
    rig.server.gate = gate

    rig.reporter.record("rain", morning)
    runCurrent()
    assertEquals(1, rig.server.calls.size)
    rig.reporter.reset()
    gate.complete(Unit)
    rig.reporter.flush()

    assertTrue(rig.grants.isEmpty())
    assertNull(rig.reporter.notice.value)
    assertFalse(rig.reporter.hasPending)
  }

  @Test
  @DisplayName("A flush cancelled by its caller still lands the report it sent")
  fun cancelledCallerDoesNotCancelTheReport() = runTest {
    val rig = rig()
    val gate = CompletableDeferred<Unit>()
    rig.server.gate = gate

    rig.reporter.record("rain", morning)
    val waiting = launch { rig.reporter.flush() }
    runCurrent()
    waiting.cancel()
    gate.complete(Unit)
    runCurrent()

    assertFalse(rig.reporter.hasPending)
    assertEquals(1, rig.grants.size)
  }

  // MARK: - Notices

  @Test
  @DisplayName("An earned heart says +1 heart")
  fun earnedNotice() = runTest {
    val rig = rig()
    rig.server.replies += granted(earned = 1)

    rig.reporter.record("rain", morning)
    rig.reporter.flush()

    assertEquals(ListenNotice.Kind.Earned, rig.reporter.notice.value?.kind)
    assertEquals(1, rig.grants.size)

    rig.reporter.advanceNotice()
    assertNull(rig.reporter.notice.value)
  }

  @Test
  @DisplayName("A notice holds the line for its four seconds, then leaves")
  fun noticeExpires() = runTest {
    val rig = rig(noticeDuration = ListenReporter.NOTICE_DURATION)
    rig.server.replies += granted(earned = 3)

    rig.reporter.record("wind", morning)
    rig.reporter.flush()
    assertEquals(ListenNotice.Kind.Earned, rig.reporter.notice.value?.kind)

    advanceTimeBy(3_999)
    assertEquals(ListenNotice.Kind.Earned, rig.reporter.notice.value?.kind)
    advanceTimeBy(2)
    assertEquals(ListenNotice.Kind.DayComplete(3), rig.reporter.notice.value?.kind)
    advanceTimeBy(4_000)
    assertNull(rig.reporter.notice.value)
  }

  @Test
  @DisplayName("The day's last heart says +1 heart, then that today's are all in")
  fun thirdListenCompletesTheDay() = runTest {
    val rig = rig()
    rig.server.replies += granted(earned = 3)

    rig.reporter.record("wind", morning)
    rig.reporter.flush()

    assertEquals(ListenNotice.Kind.Earned, rig.reporter.notice.value?.kind)
    rig.reporter.advanceNotice()
    assertEquals(ListenNotice.Kind.DayComplete(3), rig.reporter.notice.value?.kind)
    rig.reporter.advanceNotice()
    assertNull(rig.reporter.notice.value)
  }

  @Test
  @DisplayName("A listen past the day's allowance says today's are in — once a day")
  fun kindCapOncePerDay() = runTest {
    val rig = rig()
    repeat(3) { rig.server.replies += capped(AwardCap.KIND_CAP, earned = 3) }

    rig.reporter.record("rain", morning)
    rig.reporter.flush()
    assertEquals(ListenNotice.Kind.DayComplete(3), rig.reporter.notice.value?.kind)
    rig.reporter.advanceNotice()

    rig.reporter.record("waves", morning)
    rig.reporter.flush()
    assertNull(rig.reporter.notice.value)

    // The stamp outlives a relaunch.
    val relaunched = relaunch(rig)
    relaunched.reporter.record("wind", morning)
    relaunched.reporter.flush()
    assertNull(relaunched.reporter.notice.value)
  }

  @Test
  @DisplayName("An old server without the tally still falls back to the 3-a-day rule")
  fun kindCapWithoutTally() = runTest {
    val rig = rig()
    rig.server.replies += capped(AwardCap.KIND_CAP, earned = 3).copy(tally = null)

    rig.reporter.record("rain", morning)
    rig.reporter.flush()

    assertEquals(ListenNotice.Kind.DayComplete(RewardRules.trackDailyLimit), rig.reporter.notice.value?.kind)
  }

  @Test
  @DisplayName("A repeat of a track already counted today, or the day's ceiling, stays silent")
  fun duplicateAndDailyCapAreSilent() = runTest {
    val rig = rig()
    rig.server.replies += capped(AwardCap.DUPLICATE, earned = 1)
    rig.server.replies += capped(AwardCap.DAILY_CAP, earned = 1)

    rig.reporter.record("rain", morning)
    rig.reporter.record("waves", morning)
    rig.reporter.flush()

    assertNull(rig.reporter.notice.value)
    assertEquals(2, rig.grants.size, "Their absolutes still reconcile the books.")
  }

  @Test
  @DisplayName("Yesterday's listen lands its heart without a word")
  fun yesterdayIsSilent() = runTest {
    val rig = rig()
    rig.server.replies += granted(earned = 1)

    rig.reporter.record("rain", morning.minus(Duration.ofHours(24)))
    rig.reporter.flush()

    assertEquals(1, rig.grants.size)
    assertNull(rig.reporter.notice.value)
  }

  @Test
  @DisplayName("A heart answered long after the track ended lands without a word")
  fun lateAnswerIsSilent() = runTest {
    val rig = rig()
    rig.server.replies += Offline()
    rig.server.replies += granted(earned = 1)

    rig.reporter.record("rain", morning)
    rig.reporter.flush()
    rig.clock.now = morning.plus(Duration.ofMinutes(11))
    rig.reporter.flush()

    assertEquals(1, rig.grants.size)
    assertNull(rig.reporter.notice.value)
  }

  @Test
  @DisplayName("Reset clears the queue, the notice, and the day's stamp")
  fun resetForgetsEverything() = runTest {
    val rig = rig()
    rig.server.replies += granted(earned = 3)
    rig.server.replies += Offline()

    rig.reporter.record("rain", morning)
    rig.reporter.flush()
    rig.reporter.record("waves", morning)
    rig.reporter.flush()
    assertTrue(rig.reporter.hasPending)

    rig.reporter.reset()
    assertFalse(rig.reporter.hasPending)
    assertNull(rig.reporter.notice.value)
    assertNull(rig.queueBlob.value)
    assertNull(rig.stampBlob.value)

    // The next account's day is its own: its last heart is noticed afresh.
    rig.server.replies.clear()
    rig.server.replies += granted(earned = 3)
    rig.reporter.record("wind", morning)
    rig.reporter.flush()
    rig.reporter.advanceNotice()
    assertEquals(ListenNotice.Kind.DayComplete(3), rig.reporter.notice.value?.kind)
  }

  @Test
  @DisplayName("flush(timeout) reports whether anything is still queued")
  fun flushWithTimeout() = runTest {
    val rig = rig()
    assertTrue(rig.reporter.flush(Duration.ofMillis(200)))

    rig.server.replies += Offline()
    rig.reporter.record("rain", morning)
    assertFalse(rig.reporter.flush(Duration.ofMillis(200)))

    // The connection is back: the retry lands.
    assertTrue(rig.reporter.flush(Duration.ofMillis(200)))
  }

  @Test
  @DisplayName("flush(timeout) gives up on a server that doesn't answer, and the report still lands later")
  fun flushWithTimeoutOnASlowServer() = runTest {
    val rig = rig()
    val gate = CompletableDeferred<Unit>()
    rig.server.gate = gate

    rig.reporter.record("rain", morning)
    assertFalse(rig.reporter.flush(Duration.ofSeconds(3)))

    gate.complete(Unit)
    runCurrent()
    assertFalse(rig.reporter.hasPending)
    assertEquals(1, rig.grants.size)
  }

  @Test
  @DisplayName("Only 400, 403 and 404 end a listen's retries")
  fun finalErrors() {
    assertTrue(ListenReporter.isFinal(HttpFailure(400)))
    assertTrue(ListenReporter.isFinal(HttpFailure(403)))
    assertTrue(ListenReporter.isFinal(HttpFailure(404)))
    assertFalse(ListenReporter.isFinal(HttpFailure(500)))
    assertFalse(ListenReporter.isFinal(HttpFailure(429)))
    assertFalse(ListenReporter.isFinal(HttpFailure(401)))
    assertFalse(ListenReporter.isFinal(Offline()))
    assertFalse(ListenReporter.isFinal(CancellationException()))
  }
}
