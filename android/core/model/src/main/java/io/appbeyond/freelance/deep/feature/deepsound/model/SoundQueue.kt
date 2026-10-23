package io.appbeyond.freelance.deep.feature.deepsound.model

/**
 * The shared player's transport rules, free of any media framework.
 *
 * iOS repeats these inline in all three of its players (`StreamingSoundPlayer`,
 * `SoundPlayer`, `MockSoundPlayer`); here they live once. The real player gets
 * the same behaviour from ExoPlayer (`REPEAT_MODE_ALL`, a 3 s
 * `maxSeekToPreviousPosition`) and uses these for its optimistic state; the
 * mock runs on them outright.
 */
object SoundQueue {
  /** `previous()` restarts the track once more than this many seconds have played. */
  const val RESTART_THRESHOLD_SECONDS = 3.0

  /** The index a queue of [size] actually starts at when asked for [index]. */
  fun clampStart(index: Int, size: Int): Int = index.coerceIn(0, maxOf(0, size - 1))

  /** The next index, wrapping to the start — the queue repeats forever. */
  fun nextIndex(index: Int, size: Int): Int = if (size <= 0) 0 else (index + 1) % size

  /** What `previous()` does from [index] after [elapsed] seconds. */
  fun previous(elapsed: Double, index: Int, size: Int): Previous = when {
    elapsed > RESTART_THRESHOLD_SECONDS -> Previous.Restart
    size <= 0 -> Previous.GoTo(0)
    else -> Previous.GoTo((index - 1 + size) % size)
  }

  /** Seconds to seek to for a 0…1 [fraction] of [duration], clamped. */
  fun seekTarget(fraction: Double, duration: Double): Double =
    fraction.coerceIn(0.0, 1.0) * duration

  /** 0…1 position; 0 when there is no duration to measure against. */
  fun progress(elapsed: Double, duration: Double): Double =
    if (duration > 0) (elapsed / duration).coerceIn(0.0, 1.0) else 0.0

  /**
   * The queue as it can actually play: [entries] with every locked track left
   * out, starting on the entry asked for by [startIndex] — or, when that one
   * is locked, the first unlocked entry after it, wrapping round. Null when
   * nothing in [entries] is unlocked, which callers treat as "play nothing".
   *
   * iOS's `CollectionDetailView.playable` / `PlaylistView.playable`: a run
   * never carries on into a locked sound. Leaving them out of the queue
   * outright — rather than skipping them as the queue advances — is what keeps
   * the lock screen's and a headset's next/previous, which drive the player
   * directly, off them too.
   */
  fun playable(entries: List<SoundQueueEntry>, startIndex: Int): Start? {
    if (entries.isEmpty()) return null
    val asked = clampStart(startIndex, entries.size)
    val first = (0 until entries.size)
      .map { (asked + it) % entries.size }
      .firstOrNull { !entries[it].track.isLocked }
      ?: return null
    // Locked entries before the start fall away, so its index shrinks by them.
    val index = (0 until first).count { !entries[it].track.isLocked }
    return Start(entries.filterNot { it.track.isLocked }, index)
  }

  /** What [playable] hands a player: the unlocked queue and where to begin. */
  data class Start(val entries: List<SoundQueueEntry>, val index: Int)

  sealed interface Previous {
    /** Back to the start of the current track. */
    data object Restart : Previous

    /** To another track in the queue. */
    data class GoTo(val index: Int) : Previous
  }
}
