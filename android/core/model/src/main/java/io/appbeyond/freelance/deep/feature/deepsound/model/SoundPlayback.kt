package io.appbeyond.freelance.deep.feature.deepsound.model

/**
 * One immutable snapshot of the shared player: the queue, where it stands, and
 * whether it is playing. Elapsed time is deliberately not in here — it ticks
 * several times a second and lives in its own flow, so a tick never
 * recomposes everything that reads the queue.
 *
 * Mirrors the state half of iOS `SoundPlaying`. Duration comes from the
 * backend's `durationSeconds`, never from the media, exactly as iOS does.
 */
data class SoundPlayback(
  val entries: List<SoundQueueEntry> = emptyList(),
  val index: Int = 0,
  val isPlaying: Boolean = false,
  /** The player's own gain, 0…1, independent of the system volume. */
  val volume: Double = DEFAULT_VOLUME,
) {
  val currentEntry: SoundQueueEntry? get() = entries.getOrNull(index)
  val currentTrack: SoundTrack? get() = currentEntry?.track
  val collection: SoundCollection? get() = currentEntry?.collection
  val hasTrack: Boolean get() = currentEntry != null
  val duration: Double get() = currentTrack?.durationSeconds?.toDouble() ?: 0.0
  val isCurrentPlayable: Boolean get() = currentTrack?.audioUrl != null

  /** 0…1 position for [elapsed] seconds; 0 when there is no duration. */
  fun progress(elapsed: Double): Double = SoundQueue.progress(elapsed, duration)

  /** Whether [track] from [collection] is the one loaded right now. */
  fun isCurrent(track: SoundTrack, collection: SoundCollection): Boolean =
    currentTrack?.id == track.id && this.collection?.id == collection.id

  companion object {
    /** iOS starts `AVPlayer.volume` here, and so does Android. */
    const val DEFAULT_VOLUME = 0.6

    val Idle = SoundPlayback()
  }
}
