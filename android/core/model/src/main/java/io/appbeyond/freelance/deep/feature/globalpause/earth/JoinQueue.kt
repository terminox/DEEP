package io.appbeyond.freelance.deep.feature.globalpause.earth

import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint

/**
 * Arrivals waiting to flare, drained one beat apart so each reads as its own
 * person rather than a flicker — the queue half of iOS's
 * `GlobalPauseEarthScene`.
 *
 * A 5s poll delivers joins in a batch. Draining them [BEAT_MILLIS] apart
 * makes each spark land separately, but a batch must finish inside the
 * glow's rise ([BURST_WINDOW_MILLIS], one `lerpTau`), so a big batch tightens
 * its beat to fit. The queue is capped at [CAP] so a flood never keeps
 * sparking long after the moment has passed.
 *
 * The member's own arrival jumps the queue and skips the cap: it is the one
 * join the session was built for.
 */
class JoinQueue {

  private val queue = ArrayDeque<PauseJoinPoint>()

  /**
   * How many of the queue's leading entries are the member's own arrival.
   * They sit at the front, where the cap trims — so the trim starts past
   * them. iOS's `enqueueJoins` trims from index 0 and would drop an own join
   * still waiting there, against its own "a flood of strangers must never
   * trim it away".
   */
  private var ownAtFront = 0

  val size: Int get() = queue.size
  val isEmpty: Boolean get() = queue.isEmpty()

  fun enqueue(joins: List<PauseJoinPoint>) {
    queue.addAll(joins)
    while (queue.size - ownAtFront > CAP) queue.removeAt(ownAtFront)
  }

  fun enqueueOwn(join: PauseJoinPoint) {
    queue.addFirst(join)
    ownAtFront++
  }

  /**
   * The next arrival and how long to wait after flaring it, or null when
   * empty. The beat is computed BEFORE the pop, from the batch still waiting,
   * as iOS does.
   */
  fun next(): Pair<PauseJoinPoint, Long>? {
    if (queue.isEmpty()) return null
    val beat = minOf(BEAT_MILLIS, BURST_WINDOW_MILLIS / queue.size)
    if (ownAtFront > 0) ownAtFront--
    return queue.removeFirst() to beat
  }

  fun clear() {
    queue.clear()
    ownAtFront = 0
  }

  companion object {
    const val CAP = 10
    const val BEAT_MILLIS = 150L
    const val BURST_WINDOW_MILLIS = 900L
  }
}
