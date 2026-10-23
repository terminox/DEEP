package io.appbeyond.freelance.deep.feature.deepsound.player

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundPlayback
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import kotlinx.coroutines.flow.StateFlow

/**
 * The playback surface the DEEP Sound UI depends on.
 *
 * Ported from `Deep/Deep/Features/DeepSound/Player/SoundPlaying.swift`. Screens
 * depend on this rather than the concrete [SoundPlayer], so they preview and
 * test against [MockSoundPlayer] with no controller, no service and no audio.
 *
 * Where iOS exposes a dozen observable properties, this exposes two flows. The
 * derived values iOS computes on the player — `collection`, `currentTrack`,
 * `hasTrack`, `duration`, `progress` — live on [SoundPlayback] instead, so the
 * two conformers cannot disagree about them. And [elapsed] is split out from
 * [playback] on purpose: it moves four times a second, and a tick should
 * recompose the scrubber, not every tile that asks "is this the one playing?".
 */
interface SoundPlaying {

  /** The queue, where it stands, whether it is playing, and the player's gain. */
  val playback: StateFlow<SoundPlayback>

  /**
   * Seconds into the current track. Ticks every 250ms, but only while the queue
   * is playing *and* something is collecting — a mini player scrolled off
   * screen costs nothing.
   */
  val elapsed: StateFlow<Double>

  /**
   * Loads a queue and starts it. Each entry names the collection its track came
   * from, so a queue may cross collections (a playlist) or stay inside one (a
   * collection) without the player needing to know which it has.
   */
  fun play(entries: List<SoundQueueEntry>, startIndex: Int = 0)

  fun togglePlayPause()

  /**
   * Pauses if something is playing; otherwise a no-op. Guided flows (DEEP
   * Session) call this on entry — the track stays loaded so the mini player
   * picks up right where the listener left off. A member on iOS, where this is
   * a protocol extension over [togglePlayPause]; a member here so the real
   * player can refuse to start a session connection just to pause nothing.
   */
  fun pause()

  /** The next track, wrapping to the start — the queue repeats forever. */
  fun next()

  /** Restarts the track after three seconds of it; before that, the previous track. */
  fun previous()

  /** Seek to a 0…1 fraction of the current track. */
  fun seek(toProgress: Double)

  /** The player's own gain, 0…1, independent of the system volume. */
  fun setVolume(volume: Double)
}

/**
 * Starts a collection, optionally from a given track — every entry shares the
 * one collection, so the origin line stays put for the whole queue.
 */
fun SoundPlaying.play(collection: SoundCollection, startIndex: Int = 0) =
  play(collection.queue(), startIndex)
