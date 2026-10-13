package io.appbeyond.freelance.deep.feature.globalpause.earth

import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported behaviour from Deep/Deep/Features/GlobalPause/GlobalPauseEarthScene.swift (the
 * join queue and its drain beat). iOS has no tests for it; these are new, written from the
 * iOS behaviour and its stated intent.
 *
 * What it guards: a polled batch drains one beat apart so each join reads as a person, a
 * big batch tightens its beat to finish inside the glow's rise, a flood never queues more
 * than ten, and the member's own arrival goes first and is never trimmed away.
 */
class JoinQueueTest {

  private fun joins(n: Int, from: Int = 0) = List(n) { PauseJoinPoint((from + it).toFloat(), 0f) }

  private fun JoinQueue.drain(): List<Pair<PauseJoinPoint, Long>> = generateSequence { next() }.toList()

  @Test
  fun anEmptyQueueYieldsNothing() {
    val queue = JoinQueue()
    assertTrue(queue.isEmpty)
    assertNull(queue.next())
  }

  @Test
  fun drainsInArrivalOrder() {
    val queue = JoinQueue()
    queue.enqueue(joins(3))
    queue.enqueue(joins(2, from = 3))
    assertEquals(listOf(0f, 1f, 2f, 3f, 4f), queue.drain().map { it.first.lat })
  }

  @Test
  fun aFloodIsCappedAtTenDroppingTheOldest() {
    val queue = JoinQueue()
    queue.enqueue(joins(13))
    assertEquals(10, queue.size)
    assertEquals((3..12).map { it.toFloat() }, queue.drain().map { it.first.lat })
  }

  @Test
  fun beatIsTheSmallerOf150AndTheBurstWindowOverWhatIsWaiting() {
    val queue = JoinQueue()
    queue.enqueue(joins(10))
    // Computed before each pop, from the batch still waiting: 900 / n, capped at 150.
    assertEquals(
      listOf(90L, 100L, 112L, 128L, 150L, 150L, 150L, 150L, 150L, 150L),
      queue.drain().map { it.second },
    )

    queue.enqueue(joins(1))
    assertEquals(150L, queue.next()?.second)
  }

  @Test
  fun yourOwnJoinJumpsTheQueue() {
    val queue = JoinQueue()
    queue.enqueue(joins(5))
    val me = PauseJoinPoint(13.8f, 100.5f)
    queue.enqueueOwn(me)
    assertEquals(me, queue.next()?.first)
    assertEquals(0f, queue.next()?.first?.lat)
  }

  /** iOS: "a flood of strangers must never trim it away or bury it a second deep". */
  @Test
  fun yourOwnJoinSurvivesAFloodBehindIt() {
    val queue = JoinQueue()
    val me = PauseJoinPoint(13.8f, 100.5f)
    queue.enqueueOwn(me)
    queue.enqueue(joins(12))
    queue.enqueue(joins(5, from = 100))
    assertEquals(11, queue.size)
    val order = queue.drain().map { it.first }
    assertEquals(me, order.first())
    // The ten newest strangers.
    assertEquals(listOf(7f, 8f, 9f, 10f, 11f, 100f, 101f, 102f, 103f, 104f), order.drop(1).map { it.lat })
  }

  @Test
  fun yourOwnJoinSkipsTheCapOnTopOfAFullQueue() {
    val queue = JoinQueue()
    queue.enqueue(joins(10))
    val me = PauseJoinPoint(13.8f, 100.5f)
    queue.enqueueOwn(me)
    assertEquals(11, queue.size)
    assertEquals(me, queue.next()?.first)
    // Once it has flared, the cap is the strangers' again.
    queue.enqueue(joins(3, from = 50))
    assertEquals(10, queue.size)
  }

  @Test
  fun clearEmptiesTheQueue() {
    val queue = JoinQueue()
    queue.enqueueOwn(PauseJoinPoint(1f, 1f))
    queue.enqueue(joins(4))
    queue.clear()
    assertTrue(queue.isEmpty)
    // The own-join exemption doesn't outlive the clear.
    queue.enqueue(joins(12))
    assertEquals(10, queue.size)
  }
}
