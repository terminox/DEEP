package io.appbeyond.freelance.deep.feature.deepsound.player

import io.appbeyond.freelance.deep.feature.deepsound.SoundFixtures
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundPlayback
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueue
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * An in-memory [SoundPlaying] for previews and tests.
 *
 * Ported from `Deep/Deep/Features/DeepSound/Player/MockSoundPlayer.swift`.
 * State is whatever you set — no timer, no service, no audio. Transport calls
 * change state synchronously so the UI reacts, but nothing advances on its own:
 * [elapsed] stays where it was put until a seek or a skip moves it.
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
) : SoundPlaying {

  private val _playback = MutableStateFlow(
    SoundPlayback(
      entries = entries,
      index = SoundQueue.clampStart(index, entries.size),
      isPlaying = isPlaying && entries.isNotEmpty(),
      volume = volume,
    )
  )
  override val playback: StateFlow<SoundPlayback> = _playback.asStateFlow()

  private val _elapsed = MutableStateFlow(elapsed)
  override val elapsed: StateFlow<Double> = _elapsed.asStateFlow()

  override fun play(entries: List<SoundQueueEntry>, startIndex: Int) {
    _playback.value = _playback.value.copy(
      entries = entries,
      index = SoundQueue.clampStart(startIndex, entries.size),
      isPlaying = entries.isNotEmpty(),
    )
    _elapsed.value = 0.0
  }

  override fun togglePlayPause() {
    val state = _playback.value
    if (!state.hasTrack) return
    _playback.value = state.copy(isPlaying = !state.isPlaying)
  }

  override fun pause() {
    if (_playback.value.isPlaying) togglePlayPause()
  }

  override fun next() {
    val state = _playback.value
    if (!state.hasTrack) return
    _playback.value = state.copy(index = SoundQueue.nextIndex(state.index, state.entries.size))
    _elapsed.value = 0.0
  }

  override fun previous() {
    val state = _playback.value
    if (!state.hasTrack) return
    when (val move = SoundQueue.previous(_elapsed.value, state.index, state.entries.size)) {
      SoundQueue.Previous.Restart -> Unit
      is SoundQueue.Previous.GoTo -> _playback.value = state.copy(index = move.index)
    }
    _elapsed.value = 0.0
  }

  override fun seek(toProgress: Double) {
    _elapsed.value = SoundQueue.seekTarget(toProgress, _playback.value.duration)
  }

  override fun setVolume(volume: Double) {
    _playback.value = _playback.value.copy(volume = volume.coerceIn(0.0, 1.0))
  }

  companion object {
    /** Nothing loaded — the default home state. */
    fun idle(): MockSoundPlayer = MockSoundPlayer()

    /**
     * Mid-track on a collection, for player-centric screens: Ocean Depths'
     * first track, 42 seconds in, playing. Its tracks have no audio, which a
     * mock never needs.
     */
    fun playing(): MockSoundPlayer {
      val entries = SoundFixtures.oceanDepths.queue()
      val duration = entries.first().track.durationSeconds.toDouble()
      return MockSoundPlayer(
        entries = entries,
        isPlaying = true,
        elapsed = minOf(42.0, duration),
      )
    }
  }
}
