package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.feature.globalpause.model.SyncedClock
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestCoroutineScheduler
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset

/** A wall clock that reads the test scheduler's virtual time, so `delay` and
 * "now" move together. */
class SchedulerClock(
  private val scheduler: TestCoroutineScheduler,
  private val origin: Instant = ORIGIN,
) : Clock() {
  @OptIn(ExperimentalCoroutinesApi::class)
  override fun instant(): Instant = origin.plusMillis(scheduler.currentTime)
  override fun getZone(): ZoneId = ZoneOffset.UTC
  override fun withZone(zone: ZoneId): Clock = this

  companion object {
    val ORIGIN: Instant = Instant.ofEpochSecond(1_800_000_000)
  }
}

/** The session under test, on the test's virtual clock and background scope. */
fun TestScope.pauseSession(
  remote: PauseEventRemote,
  awardSink: (suspend (AwardGrant) -> Unit)? = null,
  activitySink: (suspend (Instant) -> Unit)? = null,
  introDuration: Duration = Duration.ZERO,
  clock: SyncedClock = SyncedClock(SchedulerClock(testScheduler)),
): GlobalPauseSession = GlobalPauseSession(
  clock = clock,
  remote = remote,
  scope = backgroundScope,
  presenceId = { PRESENCE_ID },
  countryIso = { "TH" },
  introDuration = { introDuration },
  awardSink = awardSink,
  activitySink = activitySink,
  // The real backoff, compressed — same shape, no multi-second waits.
  claimRetryDelays = listOf(Duration.ZERO, Duration.ofMillis(10), Duration.ofMillis(20), Duration.ofMillis(40)),
)

const val PRESENCE_ID = "install-0001"

/** The virtual now, as an instant. */
@OptIn(ExperimentalCoroutinesApi::class)
val TestScope.now: Instant get() = SchedulerClock.ORIGIN.plusMillis(testScheduler.currentTime)

/** Lets virtual time run in small steps until [condition] holds, bounded. */
@OptIn(ExperimentalCoroutinesApi::class)
fun TestScope.advanceUntil(limit: Duration = Duration.ofSeconds(5), condition: () -> Boolean) {
  runCurrent()
  var waited = Duration.ZERO
  while (!condition() && waited < limit) {
    advanceTimeBy(10)
    runCurrent()
    waited = waited.plusMillis(10)
  }
}

/** Lets virtual time run for [duration], firing everything due along the way. */
@OptIn(ExperimentalCoroutinesApi::class)
fun TestScope.advance(duration: Duration) {
  advanceTimeBy(duration.toMillis())
  runCurrent()
}
