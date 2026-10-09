package io.appbeyond.freelance.deep.feature.practice.store

import io.appbeyond.freelance.deep.feature.practice.model.PracticeCompletion
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.shared.persistence.GatedBlobStore
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import io.appbeyond.freelance.deep.shared.persistence.StoreJson
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.UUID
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** A [PracticeRemote] that always throws — simulates being offline, so
 * completions stay queued as unsynced. */
private class FailingPracticeRemote : PracticeRemote {
  class RemoteFailure : Exception()

  override suspend fun push(sessions: List<PracticeCompletion>): PracticePushResult = throw RemoteFailure()

  override suspend fun pull(): List<PracticeCompletion> = throw RemoteFailure()
}

/**
 * A [PracticeRemote] that records what it was asked to upload, optionally
 * awards, optionally parks every call on [gate], and hands back a canned
 * server log for [pull].
 */
private class RecordingPracticeRemote(
  var grant: AwardGrant? = null,
  var canned: List<PracticeCompletion> = emptyList(),
  val gate: CompletableDeferred<Unit>? = null,
) : PracticeRemote {
  val uploadedBatches = mutableListOf<List<PracticeCompletion>>()

  override suspend fun push(sessions: List<PracticeCompletion>): PracticePushResult {
    uploadedBatches += sessions
    gate?.await()
    return PracticePushResult(synced = sessions.map { it.id }, grant = grant)
  }

  override suspend fun pull(): List<PracticeCompletion> {
    gate?.await()
    return canned
  }
}

/**
 * Ported from Deep/DeepTests/PracticeDefaultsStoreTests.swift, plus the
 * Android-only behaviour: batched pushes, single-flight, and responses that
 * land after a reset.
 *
 * `PracticeDefaultsStore` there is `PracticeJournal` here; a second instance
 * on the same [InMemoryBlobStore] stands in for a relaunch on the same
 * `UserDefaults` suite.
 */
@OptIn(ExperimentalCoroutinesApi::class) // runCurrent, to park a push mid-flight.
class PracticeJournalTest {
  private val zone: ZoneId = ZoneId.of("Asia/Bangkok")

  /** 2026-07-23 12:00 Bangkok. */
  private val now: Instant = ZonedDateTime.of(2026, 7, 23, 12, 0, 0, 0, zone).toInstant()

  private val clock: Clock = Clock.fixed(now, zone)

  private fun journal(remote: PracticeRemote, blob: InMemoryBlobStore = InMemoryBlobStore()) =
    PracticeJournal(remote = remote, blob = blob, clock = clock, zone = zone)

  /** Seeds a blob as if an earlier launch had already written to it. */
  private fun seeded(completions: List<PracticeCompletion>) = InMemoryBlobStore(
    StoreJson.encodeToString(PracticeJournal.State.serializer(), PracticeJournal.State(completions = completions))
  )

  private fun pending(title: String = "Balancing breath", at: Instant = now, synced: Boolean = false) =
    PracticeCompletion(
      id = UUID.randomUUID(),
      title = title,
      durationSeconds = 300,
      completedAt = at,
      isSynced = synced,
    )

  // MARK: - Persistence

  @Test
  fun recordPersistsAcrossASecondStoreInstance() = runTest {
    val blob = InMemoryBlobStore()

    journal(MockPracticeRemote(), blob).record("Balancing breath", durationSeconds = 60)

    val relaunched = journal(MockPracticeRemote(), blob)
    relaunched.restore()
    assertEquals(1, relaunched.completions.size)
    assertEquals("Balancing breath", relaunched.completions.first().title)
    assertEquals(now, relaunched.completions.first().completedAt)
    assertEquals(10, relaunched.dailyGoalMinutes)
  }

  // MARK: - Sync

  @Test
  fun recordIsUnsyncedThenSyncedAfterAcceptingRefresh() = runTest {
    val journal = journal(RecordingPracticeRemote())

    journal.record("Balancing breath", durationSeconds = 60)
    assertFalse(journal.completions.first().isSynced)

    journal.refresh()
    assertTrue(journal.completions.first().isSynced)
  }

  @Test
  fun offlineEntriesStayUnsyncedButStillCountTowardMinutesToday() = runTest {
    val journal = journal(FailingPracticeRemote())

    journal.record("Balancing breath", durationSeconds = 60)
    journal.refresh()

    assertFalse(journal.completions.first().isSynced)
    assertEquals(1, journal.minutesToday())
  }

  // MARK: - Award sink

  @Test
  fun syncForwardsAwardsToSink() = runTest {
    val grant = AwardGrant(hearts = 1, sunlight = 1, plantId = "oak", heartsBalance = 7, plantSunlight = 241)
    val journal = journal(RecordingPracticeRemote(grant = grant), seeded(listOf(pending())))
    val received = mutableListOf<AwardGrant>()
    journal.awardSink = { received += it }

    journal.refresh()
    assertEquals(listOf(grant), received)
    assertTrue(journal.completions.first().isSynced)
  }

  @Test
  fun syncWithoutAwardsLeavesSinkUntouched() = runTest {
    val journal = journal(RecordingPracticeRemote(), seeded(listOf(pending())))
    val received = mutableListOf<AwardGrant>()
    journal.awardSink = { received += it }

    journal.refresh()
    assertTrue(received.isEmpty())
    assertTrue(journal.completions.first().isSynced)
  }

  // MARK: - Pull merge

  @Test
  fun pullMergesServerOnlyEntriesByIdWithoutDuplicatingKnownIds() = runTest {
    val known = pending(title = "Known locally", synced = true)
    val remote = RecordingPracticeRemote(
      canned = listOf(known, pending(title = "Server only", synced = false)),
    )
    val journal = journal(remote, seeded(listOf(known)))
    journal.restore()
    assertEquals(1, journal.completions.size)

    journal.refresh()
    assertEquals(2, journal.completions.size)
    assertEquals(1, journal.completions.count { it.id == known.id })
    assertTrue(journal.completions.all { it.isSynced }, "Pulled entries arrive synced.")
  }

  @Test
  @DisplayName("Pulled entries merge in completion order and never rewrite a known entry")
  fun pullSortsAndKeepsKnownEntries() = runTest {
    val local = pending(title = "Local", at = now, synced = false)
    val earlier = pending(title = "Earlier elsewhere", at = now.minusSeconds(3_600), synced = true)
    val remote = RecordingPracticeRemote(canned = listOf(local.copy(title = "Renamed on server"), earlier))
    val journal = journal(remote, seeded(listOf(local)))

    journal.pull()

    assertEquals(listOf("Earlier elsewhere", "Local"), journal.completions.map { it.title })
    assertFalse(journal.completions.last().isSynced, "Pull never marks a local entry synced.")
  }

  // MARK: - Reset

  @Test
  fun resetEmptiesAndPersists() = runTest {
    val blob = InMemoryBlobStore()
    val journal = journal(MockPracticeRemote(), blob)
    journal.record("Balancing breath", durationSeconds = 60)
    assertTrue(journal.completions.isNotEmpty())

    journal.reset()
    assertTrue(journal.completions.isEmpty())

    val relaunched = journal(MockPracticeRemote(), blob)
    relaunched.restore()
    assertTrue(relaunched.completions.isEmpty())
  }

  // MARK: - Batching & single-flight

  @Test
  @DisplayName("A long offline backlog goes up in batches of at most 200")
  fun pushChunksLargeBacklogs() = runTest {
    val remote = RecordingPracticeRemote(grant = AwardGrant(hearts = 1, sunlight = 1, plantId = "oak"))
    val journal = journal(remote, seeded(List(450) { pending() }))
    val received = mutableListOf<AwardGrant>()
    journal.awardSink = { received += it }

    journal.push()

    assertEquals(listOf(200, 200, 50), remote.uploadedBatches.map { it.size })
    assertEquals(450, remote.uploadedBatches.flatten().map { it.id }.toSet().size)
    assertTrue(journal.completions.all { it.isSynced })
    assertEquals(3, received.size, "Each batch's awards are forwarded.")
  }

  @Test
  @DisplayName("A failed batch stops the push and leaves the rest unsynced")
  fun pushStopsAtFirstFailure() = runTest {
    var calls = 0
    val remote = object : PracticeRemote {
      override suspend fun push(sessions: List<PracticeCompletion>): PracticePushResult {
        calls++
        if (calls == 2) throw IllegalStateException("offline")
        return PracticePushResult(synced = sessions.map { it.id }, grant = null)
      }

      override suspend fun pull(): List<PracticeCompletion> = emptyList()
    }
    val journal = journal(remote, seeded(List(450) { pending() }))

    journal.push()

    assertEquals(2, calls)
    assertEquals(200, journal.completions.count { it.isSynced })
  }

  @Test
  @DisplayName("Concurrent pushes never offer the same session twice")
  fun pushIsSingleFlight() = runTest {
    val gate = CompletableDeferred<Unit>()
    val remote = RecordingPracticeRemote(gate = gate)
    val journal = journal(remote, seeded(List(3) { pending() }))

    val first = launch { journal.push() }
    val second = launch { journal.push() }
    runCurrent()
    assertEquals(1, remote.uploadedBatches.size, "The second push waits behind the first.")

    gate.complete(Unit)
    first.join()
    second.join()

    assertEquals(1, remote.uploadedBatches.size)
    assertEquals(3, remote.uploadedBatches.single().size)
    assertTrue(journal.completions.all { it.isSynced })
  }

  // MARK: - Sign-out

  @Test
  @DisplayName("A push that lands after reset neither re-adds entries nor forwards awards")
  fun latePushAfterResetIsDropped() = runTest {
    val gate = CompletableDeferred<Unit>()
    val remote = RecordingPracticeRemote(
      grant = AwardGrant(hearts = 1, sunlight = 1, plantId = "oak", heartsBalance = 9),
      gate = gate,
    )
    val blob = seeded(List(2) { pending() })
    val journal = journal(remote, blob)
    val received = mutableListOf<AwardGrant>()
    journal.awardSink = { received += it }

    val pushing = launch { journal.push() }
    runCurrent()
    journal.reset()
    gate.complete(Unit)
    pushing.join()

    assertTrue(journal.completions.isEmpty())
    assertTrue(received.isEmpty())
    val relaunched = journal(MockPracticeRemote(), blob)
    relaunched.restore()
    assertTrue(relaunched.completions.isEmpty())
  }

  @Test
  @DisplayName("A pull that lands after reset merges nothing")
  fun latePullAfterResetIsDropped() = runTest {
    val gate = CompletableDeferred<Unit>()
    val remote = RecordingPracticeRemote(canned = listOf(pending(synced = true)), gate = gate)
    val journal = journal(remote)

    val pulling = launch { journal.pull() }
    runCurrent()
    journal.reset()
    gate.complete(Unit)
    pulling.join()

    assertTrue(journal.completions.isEmpty())
  }

  // MARK: - Derived

  @Test
  @DisplayName("The garden's practice card projects from the journal")
  fun gardenStateProjection() = runTest {
    val journal = journal(MockPracticeRemote())
    journal.record("Balancing breath", durationSeconds = 420)

    val garden = journal.gardenState()
    assertEquals(7, garden.minutesToday)
    assertEquals(10, garden.dailyGoalMinutes)
    assertEquals(1, garden.streakDays)
    assertEquals(3, garden.minutesRemaining)
    assertEquals(1, journal.completionsToday())
  }

  // MARK: - Races (peer review)

  @Test
  @DisplayName("A reset while a batch's awards are being delivered stops the next batch")
  fun resetBetweenBatchesStopsTheNextBatch() = runTest {
    val sinkGate = CompletableDeferred<Unit>()
    val remote = RecordingPracticeRemote(grant = AwardGrant(hearts = 1, sunlight = 1, plantId = "oak"))
    val journal = journal(remote, seeded(List(201) { pending() }))
    val received = mutableListOf<AwardGrant>()
    journal.awardSink = {
      received += it
      sinkGate.await()
    }

    val pushing = launch { journal.push() }
    runCurrent() // Batch one uploaded; its award is being delivered.
    journal.reset()
    sinkGate.complete(Unit)
    pushing.join()

    assertEquals(1, remote.uploadedBatches.size, "The old account's second batch must never go up.")
    assertEquals(1, received.size)
    assertTrue(journal.completions.isEmpty())
  }

  @Test
  @DisplayName("A record cancelled while saving still survives a relaunch")
  fun cancelledRecordIsStillPersisted() = runTest {
    val blob = GatedBlobStore()
    val journal = PracticeJournal(MockPracticeRemote(), blob, clock, zone)
    journal.restore()
    blob.armed = true

    val recording = launch { journal.record("Balancing breath", durationSeconds = 60) }
    runCurrent()
    recording.cancel()
    blob.gate.complete(Unit)
    recording.join()

    val relaunched = PracticeJournal(MockPracticeRemote(), blob, clock, zone)
    relaunched.restore()
    assertEquals(1, relaunched.completions.size)
  }

  @Test
  @DisplayName("A push cancelled after its batch was accepted still delivers that batch's awards")
  fun cancelledPushStillDeliversAwards() = runTest {
    val grant = AwardGrant(hearts = 1, sunlight = 1, plantId = "oak", heartsBalance = 7)
    val blob = GatedBlobStore(
      StoreJson.encodeToString(PracticeJournal.State.serializer(), PracticeJournal.State(listOf(pending())))
    )
    val journal = PracticeJournal(RecordingPracticeRemote(grant = grant), blob, clock, zone)
    journal.restore()
    val received = mutableListOf<AwardGrant>()
    journal.awardSink = { received += it }
    blob.armed = true

    val pushing = launch { journal.push() }
    runCurrent() // Accepted, marked synced, parked writing that to disk.
    pushing.cancel()
    blob.gate.complete(Unit)
    pushing.join()

    assertEquals(listOf(grant), received)
    assertTrue(journal.completions.single().isSynced)
  }
}
