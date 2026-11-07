package io.appbeyond.freelance.deep.feature.deepsound.model

import kotlin.random.Random

/**
 * What plays, in which order, and what comes next — the rules every
 * `SoundPlaying` and the sound service share, with no audio attached.
 *
 * Ported from Deep/Deep/Features/DeepSound/Player/SoundQueue.swift. [entries]
 * keep the order they arrived in; [order] is the play order over them (the
 * identity, or a shuffle), and [position] walks [order]. An entry the holder
 * can't play (for the streaming player, one with no audio) is skipped at every
 * step.
 *
 * Immutable where the iOS struct mutates: every move returns the queue it leads
 * to, so a [SoundPlayback] snapshot can hold one safely. Generic over the entry
 * because two holders keep a queue — `SoundPlayer` over [SoundQueueEntry]s, and
 * the sound service over the media items its player holds — and both must
 * answer by these same rules.
 */
class SoundQueue<E> private constructor(
  val entries: List<E>,
  /** Play order, as indices into [entries]. */
  val order: List<Int>,
  /** Where in [order] the current entry sits. */
  val position: Int,
  val repeatMode: RepeatMode,
  val isShuffled: Boolean,
  private val canPlay: (E) -> Boolean,
) {

  // MARK: Reading

  val isEmpty: Boolean get() = entries.isEmpty()

  /** Where the current entry sits in [entries] — the index a player's list holds it at. */
  val currentIndex: Int? get() = order.getOrNull(position)

  val current: E? get() = currentIndex?.let(entries::get)

  /** What starts when the current entry ends on its own; null when the queue stops there. */
  val upcoming: E? get() = upcomingPosition?.let { entries[order[it]] }

  private val upcomingPosition: Int?
    get() {
      if (order.isEmpty()) return null
      return when (repeatMode) {
        RepeatMode.One ->
          if (isPlayable(position)) position else nextPlayable(position, wrapping = false)?.position
        RepeatMode.All -> nextPlayable(position, wrapping = true)?.position
        RepeatMode.Off -> nextPlayable(position, wrapping = false)?.position
      }
    }

  // MARK: Moving

  /**
   * The current entry ended on its own. Moves to [upcoming], carrying on; at
   * the end of an unrepeated queue it returns to the first entry and does not
   * carry on — the queue has finished.
   */
  fun advanceAfterEnd(): Move<E> {
    upcomingPosition?.let { return Move(copy(position = it), carriesOn = true) }
    return Move(rewound(), carriesOn = false)
  }

  /**
   * The listener skipped forward. Always moves on, Repeat One included, and
   * wraps from the last entry to the first. Carries on playing — but not after
   * wrapping an unrepeated queue, and not when nothing in it can play.
   */
  fun skipForward(): Move<E> {
    val next = nextPlayable(position, wrapping = true) ?: return Move(this, carriesOn = false)
    return Move(
      copy(position = next.position),
      carriesOn = !next.wrapped || repeatMode == RepeatMode.All,
    )
  }

  /**
   * The listener skipped back. Moves to the previous entry; at the first entry
   * of a queue not on Repeat All there is nowhere to go, and it does not move —
   * so the caller restarts the current one instead.
   */
  fun skipBack(): Move<E> {
    if (order.size <= 1) return Move(this, carriesOn = false)
    for (step in 1 until order.size) {
      val raw = position - step
      if (raw < 0 && repeatMode != RepeatMode.All) return Move(this, carriesOn = false)
      val candidate = (raw + order.size) % order.size
      if (isPlayable(candidate)) return Move(copy(position = candidate), carriesOn = true)
    }
    return Move(this, carriesOn = false)
  }

  /**
   * The current entry could not play. Moves to the next one that might — past
   * Repeat One, which would only fail again — and carries on; at the end of a
   * queue not on Repeat All it returns to the first entry and does not.
   */
  fun skipUnplayable(): Move<E> {
    nextPlayable(position, wrapping = repeatMode == RepeatMode.All)?.let {
      return Move(copy(position = it.position), carriesOn = true)
    }
    return Move(rewound(), carriesOn = false)
  }

  fun withRepeatMode(mode: RepeatMode): SoundQueue<E> = copy(repeatMode = mode)

  /**
   * Shuffling keeps the current entry where it is and deals the rest in a
   * random order after it; un-shuffling restores the original order, still on
   * the current entry.
   */
  fun withShuffle(shuffled: Boolean, random: Random): SoundQueue<E> {
    if (shuffled == isShuffled) return this
    val currentIndex = currentIndex ?: return copy(isShuffled = shuffled)
    return if (shuffled) {
      copy(order = dealt(currentIndex, entries.size, random), position = 0, isShuffled = true)
    } else {
      copy(order = entries.indices.toList(), position = currentIndex, isShuffled = false)
    }
  }

  /** A new queue over different entries, keeping this one's repeat mode and playability rule. */
  fun replacing(entries: List<E>, startIndex: Int?, shuffled: Boolean, random: Random): SoundQueue<E> =
    start(entries, startIndex, shuffled, repeatMode, canPlay, random)

  /**
   * This queue as another holder of it keeps it — the play order it dealt, the
   * entry it stands on, and its modes. Null when [order] is not a play order
   * over these entries (the holder has a different queue), so the caller keeps
   * what it has.
   */
  fun adopting(order: List<Int>, currentIndex: Int, repeatMode: RepeatMode, isShuffled: Boolean): SoundQueue<E>? =
    restore(entries, order, currentIndex, repeatMode, isShuffled, canPlay)

  // MARK: Helpers

  private fun isPlayable(position: Int): Boolean = canPlay(entries[order[position]])

  /** Back to the first entry that can play — where a finished queue rests. */
  private fun rewound(): SoundQueue<E> =
    copy(position = order.indices.firstOrNull { isPlayable(it) } ?: 0)

  /**
   * The next playable position after [position], and whether reaching it meant
   * wrapping past the end. With wrapping, a lone playable entry finds itself.
   */
  private fun nextPlayable(position: Int, wrapping: Boolean): Found? {
    if (order.isEmpty()) return null
    for (step in 1..order.size) {
      val raw = position + step
      val wrapped = raw >= order.size
      if (wrapped && !wrapping) return null
      val candidate = raw % order.size
      if (isPlayable(candidate)) return Found(candidate, wrapped)
    }
    return null
  }

  private class Found(val position: Int, val wrapped: Boolean)

  private fun copy(
    order: List<Int> = this.order,
    position: Int = this.position,
    repeatMode: RepeatMode = this.repeatMode,
    isShuffled: Boolean = this.isShuffled,
  ): SoundQueue<E> = SoundQueue(entries, order, position, repeatMode, isShuffled, canPlay)

  /** Where a move led, and whether playback should carry on there. */
  data class Move<E>(val queue: SoundQueue<E>, val carriesOn: Boolean)

  companion object {
    /** `previous()` restarts the track once more than this many seconds have played. */
    const val RESTART_THRESHOLD_SECONDS = 3.0

    /** The streaming player's rule: an entry plays when it has audio to stream. */
    val hasAudio: (SoundQueueEntry) -> Boolean = { it.track.audioUrl != null }

    /** Nothing queued yet, already holding the listener's [repeatMode]. */
    fun <E> empty(repeatMode: RepeatMode = RepeatMode.Off, canPlay: (E) -> Boolean): SoundQueue<E> =
      SoundQueue(emptyList(), emptyList(), 0, repeatMode, isShuffled = false, canPlay = canPlay)

    /**
     * A queue over [entries], starting from [startIndex] — or, shuffled with no
     * index, from a random entry that can play. Shuffled, the start plays first
     * and the rest follow in random order. A start that can't play moves on to
     * the next entry that can.
     */
    fun <E> start(
      entries: List<E>,
      startIndex: Int?,
      shuffled: Boolean,
      repeatMode: RepeatMode,
      canPlay: (E) -> Boolean,
      random: Random,
    ): SoundQueue<E> {
      if (entries.isEmpty()) return SoundQueue(entries, emptyList(), 0, repeatMode, shuffled, canPlay)
      val start = when {
        startIndex != null -> clampStart(startIndex, entries.size)
        shuffled -> entries.indices.filter { canPlay(entries[it]) }.randomOrNull(random) ?: 0
        else -> 0
      }
      val queue = if (shuffled) {
        SoundQueue(entries, dealt(start, entries.size, random), 0, repeatMode, true, canPlay)
      } else {
        SoundQueue(entries, entries.indices.toList(), start, repeatMode, false, canPlay)
      }
      if (queue.isPlayable(queue.position)) return queue
      val found = queue.nextPlayable(queue.position, wrapping = true) ?: return queue
      return queue.copy(position = found.position)
    }

    /**
     * A queue another holder dealt: [order] over [entries], standing on
     * [currentIndex]. Null when [order] is not a permutation of the entries'
     * indices or does not hold [currentIndex].
     */
    fun <E> restore(
      entries: List<E>,
      order: List<Int>,
      currentIndex: Int,
      repeatMode: RepeatMode,
      isShuffled: Boolean,
      canPlay: (E) -> Boolean,
    ): SoundQueue<E>? {
      if (order.size != entries.size || order.sorted() != entries.indices.toList()) return null
      val position = order.indexOf(currentIndex).takeIf { it >= 0 } ?: return null
      return SoundQueue(entries, order, position, repeatMode, isShuffled, canPlay)
    }

    /** [start] first, then every other index of [size] in a random order. */
    private fun dealt(start: Int, size: Int, random: Random): List<Int> =
      listOf(start) + (0 until size).filter { it != start }.shuffled(random)

    /** The index a queue of [size] actually starts at when asked for [index]. */
    fun clampStart(index: Int, size: Int): Int = index.coerceIn(0, maxOf(0, size - 1))

    /** Seconds to seek to for a 0…1 [fraction] of [duration], clamped. */
    fun seekTarget(fraction: Double, duration: Double): Double =
      fraction.coerceIn(0.0, 1.0) * duration

    /** 0…1 position; 0 when there is no duration to measure against. */
    fun progress(elapsed: Double, duration: Double): Double =
      if (duration > 0) (elapsed / duration).coerceIn(0.0, 1.0) else 0.0

    /**
     * [entries] as a player can actually hold them, and where to begin.
     *
     * Every locked entry is left out: iOS's `CollectionDetailView.playable` /
     * `PlaylistView.playable`, a run never carries on into a locked sound.
     * Once anything left has audio, every entry without any leaves too — the
     * queue skips those at every step anyway, and a player's own list holding
     * only what it can stream is what keeps a track ending in the background
     * (which the service's player moves past on its own) from landing on one.
     * A queue with no audio at all (fixture content) is kept whole, and loads
     * paused, as iOS's does.
     *
     * The start is the entry asked for by [startIndex] — or, when that one has
     * left, the first one after it that stayed, wrapping round. A null
     * [startIndex] stays null: a shuffle picks its own. Null when nothing in
     * [entries] is unlocked, which callers treat as "play nothing".
     */
    fun playable(entries: List<SoundQueueEntry>, startIndex: Int?): Start? {
      val unlocked = entries.indices.filterNot { entries[it].track.isLocked }
      if (unlocked.isEmpty()) return null
      val kept = unlocked.filter { hasAudio(entries[it]) }.ifEmpty { unlocked }
      val queue = kept.map { entries[it] }
      if (startIndex == null) return Start(queue, null)
      val asked = clampStart(startIndex, entries.size)
      val first = entries.indices.map { (asked + it) % entries.size }.first { it in kept }
      return Start(queue, kept.indexOf(first))
    }
  }

  /** What [playable] hands a player: the queue it can hold, and where to begin. */
  data class Start(val entries: List<SoundQueueEntry>, val index: Int?)
}
