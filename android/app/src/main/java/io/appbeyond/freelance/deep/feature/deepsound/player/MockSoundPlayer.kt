package io.appbeyond.freelance.deep.feature.deepsound.player

import io.appbeyond.freelance.deep.feature.deepsound.SoundFixtures
import io.appbeyond.freelance.deep.feature.deepsound.model.RepeatMode
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundPlayback
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueue
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.random.Random

/**
 * An in-memory [SoundPlaying] for previews and tests.
 *
 * Ported from `Deep/Deep/Features/DeepSound/Player/MockSoundPlayer.swift`.
 * State is whatever you set — no timer, no service, no audio. Transport calls
 * change state synchronously so the UI reacts, but nothing advances on its own:
 * [elapsed] stays where it was put until a seek or a skip moves it. The queue
 * rules are the real ones — [SoundQueue] — with every track counting as
 * playable, as iOS's mock does: fixture tracks carry no audio.
 *
 * Not `DEBUG`-gated, unlike the iOS original: an Android preview compiles into
 * every variant, and R8 strips this from a release build that never names it.
 */
class MockSoundPlayer(
  entries: List<SoundQueueEntry> = emptyList(),
  index: Int = 0,
  isPlaying: Boolean = false,
  elapsed: Double = 0.0,
  volume: Double = SoundPlayback.DEFAULT_VOLUME,
  repeatMode: RepeatMode = RepeatMode.Off,
  isShuffled: Boolean = false,
) : SoundPlaying {

  /** Seeded, so a preview deals the same shuffle every time it renders. */
  private val random = Random(SEED)

  private val _playback = MutableStateFlow(
    SoundPlayback(
      queue = SoundQueue.start(entries, index, isShuffled, repeatMode, everyTrackPlays, random),
      isPlaying = isPlaying && entries.isNotEmpty(),
      volume = volume,
    )
  )
  override val playback: StateFlow<SoundPlayback> = _playback.asStateFlow()

  private val _elapsed = MutableStateFlow(elapsed)
  override val elapsed: StateFlow<Double> = _elapsed.asStateFlow()

  override fun play(entries: List<SoundQueueEntry>, startIndex: Int?, shuffled: Boolean) {
    val state = _playback.value
    if (entries.isEmpty()) {
      _playback.value = state.copy(queue = state.queue.replacing(emptyList(), null, false, random), isPlaying = false)
      _elapsed.value = 0.0
      return
    }
    if (isPlaybackHeld) return
    // The real player's rule: locked tracks never join the queue.
    val start = SoundQueue.playable(entries, startIndex) ?: return
    _playback.value = state.copy(
      queue = state.queue.replacing(start.entries, start.index, shuffled, random),
      isPlaying = true,
    )
    _elapsed.value = 0.0
  }

  override fun togglePlayPause() {
    val state = _playback.value
    if (!state.hasTrack) return
    if (!state.isPlaying && isPlaybackHeld) return
    _playback.value = state.copy(isPlaying = !state.isPlaying)
  }

  override var isPlaybackHeld: Boolean = false
    private set

  override fun holdPlayback(held: Boolean) {
    isPlaybackHeld = held
    if (held) pause()
  }

  override fun pause() {
    if (_playback.value.isPlaying) togglePlayPause()
  }

  override fun next() {
    val state = _playback.value
    if (!state.hasTrack) return
    val (queue, carriesOn) = state.queue.skipForward()
    _playback.value = state.copy(queue = queue, isPlaying = state.isPlaying && carriesOn)
    _elapsed.value = 0.0
  }

  override fun previous() {
    val state = _playback.value
    if (!state.hasTrack) return
    if (_elapsed.value <= SoundQueue.RESTART_THRESHOLD_SECONDS) {
      _playback.value = state.copy(queue = state.queue.skipBack().queue)
    }
    _elapsed.value = 0.0
  }

  override fun seek(toProgress: Double) {
    _elapsed.value = SoundQueue.seekTarget(toProgress, _playback.value.duration)
  }

  override fun setVolume(volume: Double) {
    _playback.value = _playback.value.copy(volume = volume.coerceIn(0.0, 1.0))
  }

  override fun setRepeatMode(mode: RepeatMode) {
    val state = _playback.value
    _playback.value = state.copy(queue = state.queue.withRepeatMode(mode))
  }

  override fun setShuffled(shuffled: Boolean) {
    val state = _playback.value
    _playback.value = state.copy(queue = state.queue.withShuffle(shuffled, random))
  }

  companion object {
    private const val SEED = 7

    private val everyTrackPlays: (SoundQueueEntry) -> Boolean = { true }

    /** Nothing loaded — the default home state. */
    fun idle(): MockSoundPlayer = MockSoundPlayer()

    /**
     * Mid-track on a collection, for player-centric screens: Ocean Depths'
     * first track, 42 seconds in, playing. Its tracks have no audio, which a
     * mock never needs.
     */
    fun playing(
      repeatMode: RepeatMode = RepeatMode.Off,
      isShuffled: Boolean = false,
    ): MockSoundPlayer {
      val entries = SoundFixtures.oceanDepths.queue()
      val duration = entries.first().track.durationSeconds.toDouble()
      return MockSoundPlayer(
        entries = entries,
        isPlaying = true,
        elapsed = minOf(42.0, duration),
        repeatMode = repeatMode,
        isShuffled = isShuffled,
      )
    }
  }
}
