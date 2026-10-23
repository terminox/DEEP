package io.appbeyond.freelance.deep.feature.globalpause.store

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Duration

/**
 * The audio surface of a Global Pause — a deliberately smaller contract than
 * DEEP Sound's `SoundPlaying`.
 *
 * There is no pause, no seek, no transport of any kind: the meditation is one
 * unbroken sit, and leaving the session is the only way out. Keeping those
 * affordances off the interface makes "cannot be paused" true by construction
 * rather than by UI discipline. The shared DEEP Sound player is paused on
 * session entry and never sees this audio, so the mini player never surfaces
 * it.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Audio/GlobalPauseAudioPlaying.swift.
 */
interface GlobalPauseAudioPlaying {

  /** True while the meditation stream is playing (or recovering to play). */
  val isMeditating: StateFlow<Boolean>

  /** How far into the meditation stream the player is. Zero outside it. */
  val meditationElapsed: StateFlow<Duration>

  /**
   * Recovery seam: after an interruption or stall the player re-seeks to
   * whatever offset this returns — the session wires it to "synced now −
   * meditation start", so recovery lands back on the live edge.
   */
  var meditationOffsetProvider: (() -> Duration)?

  /** Joins the meditation stream [offset] in. Past [duration], silence. */
  fun playMeditation(url: String, offset: Duration, duration: Duration)

  /** Re-seeks to the live edge (interruption recovery, clock corrections). */
  fun realignMeditation(offset: Duration)

  /** Tears everything down. Idempotent. */
  fun stop()
}

/**
 * A silent stand-in for previews and tests: it reports a meditation without
 * playing one, and lets a test drive the clock.
 */
class MockGlobalPauseAudioPlayer(
  meditating: Boolean = false,
  elapsed: Duration = Duration.ZERO,
) : GlobalPauseAudioPlaying {

  private val _isMeditating = MutableStateFlow(meditating)
  override val isMeditating: StateFlow<Boolean> = _isMeditating.asStateFlow()

  private val _elapsed = MutableStateFlow(elapsed)
  override val meditationElapsed: StateFlow<Duration> = _elapsed.asStateFlow()

  override var meditationOffsetProvider: (() -> Duration)? = null

  /** Every stream asked for, for assertions. */
  val played = mutableListOf<Pair<String, Duration>>()
  var stopCount = 0
    private set

  override fun playMeditation(url: String, offset: Duration, duration: Duration) {
    played += url to offset
    if (offset >= duration) return
    _isMeditating.value = true
    _elapsed.value = offset
  }

  override fun realignMeditation(offset: Duration) {
    _elapsed.value = offset
  }

  override fun stop() {
    stopCount += 1
    _isMeditating.value = false
    _elapsed.value = Duration.ZERO
  }

  /** Moves the reported clock, as the real player's periodic tick would. */
  fun advance(to: Duration) {
    _elapsed.value = to
  }

  companion object {
    /** Five minutes into a ten-minute meditation. */
    fun meditating(): MockGlobalPauseAudioPlayer =
      MockGlobalPauseAudioPlayer(meditating = true, elapsed = Duration.ofMinutes(5))
  }
}
