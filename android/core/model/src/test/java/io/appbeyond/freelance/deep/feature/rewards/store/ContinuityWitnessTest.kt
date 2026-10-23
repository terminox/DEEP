package io.appbeyond.freelance.deep.feature.rewards.store

import io.appbeyond.freelance.deep.shared.persistence.GatedBlobStore
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/ContinuityWitnessTests.swift.
 *
 * The one day-stamp behind the continuity beat: it is spent once a day, it
 * survives a relaunch, and it lets go on its own when the day turns.
 */
@OptIn(ExperimentalCoroutinesApi::class) // runCurrent, to park a write mid-flight.
class ContinuityWitnessTest {

  private val zone: ZoneId = ZoneId.of("Asia/Bangkok")

  private val today: Instant = Instant.ofEpochSecond(1_800_000_000)

  private fun witness(blob: InMemoryBlobStore, now: Instant = today) =
    ContinuityWitness(blob = blob, clock = Clock.fixed(now, zone), zone = zone)

  @Test
  @DisplayName("A day nobody has witnessed starts open")
  fun startsUnwitnessed() = runTest {
    assertFalse(witness(InMemoryBlobStore()).hasWitnessedToday())
  }

  @Test
  @DisplayName("Witnessing spends today, and stays spent on re-read")
  fun witnessingSpendsTheDay() = runTest {
    val blob = InMemoryBlobStore()
    val witness = witness(blob)

    witness.witnessToday()
    assertTrue(witness.hasWitnessedToday())

    // A relaunch reads the same stamp back.
    assertTrue(witness(blob).hasWitnessedToday())
  }

  @Test
  @DisplayName("A witnessed day lets go once the day turns")
  fun dayRollover() = runTest {
    val blob = InMemoryBlobStore()
    val tomorrow = today.plus(Duration.ofHours(24))

    witness(blob, now = today).witnessToday()

    assertTrue(witness(blob, now = today).hasWitnessedToday())
    assertFalse(witness(blob, now = tomorrow).hasWitnessedToday())
  }

  @Test
  @DisplayName("Signing out forgets the day, so the next account meets its own rhythm")
  fun resetForgetsTheDay() = runTest {
    val blob = InMemoryBlobStore()
    val witness = witness(blob)

    witness.witnessToday()
    witness.resetLocalState()

    assertFalse(witness.hasWitnessedToday())
    assertFalse(witness(blob).hasWitnessedToday())
    assertNull(blob.value)
  }

  @Test
  @DisplayName("Witnessing twice in a day keeps the first stamp")
  fun secondWitnessIsANoOp() = runTest {
    val blob = InMemoryBlobStore()
    witness(blob, now = today).witnessToday()
    val later = witness(blob, now = today.plus(Duration.ofHours(1)))

    later.witnessToday()

    assertEquals(today, later.lastWitnessed.value)
    assertEquals(1, blob.writes)
  }

  @Test
  @DisplayName("A stamp still being written when the account signs out never comes back")
  fun witnessWriteNeverOutlivesReset() = runTest {
    val blob = GatedBlobStore()
    val witness = ContinuityWitness(blob = blob, clock = Clock.fixed(today, zone), zone = zone)
    witness.restore()
    blob.armed = true

    val witnessing = launch { witness.witnessToday() }
    runCurrent() // Parked writing today's stamp.
    blob.armed = false
    val resetting = launch { witness.resetLocalState() }
    runCurrent()
    blob.gate.complete(Unit)
    witnessing.join()
    resetting.join()

    assertNull(blob.value)
    assertFalse(witness.hasWitnessedToday())
    assertFalse(ContinuityWitness(blob = blob, clock = Clock.fixed(today, zone), zone = zone).hasWitnessedToday())
  }
}
