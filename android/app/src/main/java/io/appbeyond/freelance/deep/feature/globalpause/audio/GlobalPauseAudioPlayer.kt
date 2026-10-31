package io.appbeyond.freelance.deep.feature.globalpause.audio

import android.content.Context
import android.util.Log
import androidx.annotation.OptIn
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import io.appbeyond.freelance.deep.feature.globalpause.store.GlobalPauseAudioPlaying
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import java.time.Duration

/**
 * The real Global Pause audio engine: a bare [ExoPlayer] for the meditation
 * stream, over the media client from the backend's `/media/` route.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Audio/GlobalPauseAudioPlayer.swift.
 * "Cannot be paused" holds the same three ways, in Android's terms:
 *
 * 1. The interface exposes no pause, seek or transport at all.
 * 2. No `MediaSession`, so the lock screen, the notification and a headset
 *    have nothing of this player to press. (iOS refuses each remote command
 *    instead; Android simply never offers them.)
 * 3. Whatever stops it mid-meditation, it rejoins at the **live edge** — the
 *    shared stream has moved on — through [meditationOffsetProvider]: after a
 *    stall or an error, as a phone call's transient focus loss ends, and when
 *    the member comes back to the app.
 *
 * **Stalls.** iOS re-seeks the moment `AVPlayerItem` reports a stall. Seeking
 * a starved ExoPlayer only starts another buffer, so here the rejoin comes as
 * a stall clears: back to ready, a stream that fell more than [STALL_DRIFT]
 * behind the shared offset jumps to it. Only a stall counts — the buffering
 * that follows a seek of our own already lands on the live edge.
 *
 * **Audio focus** is the one place Android's contract wins over iOS's. The
 * player takes focus as it starts, which quiets anything else — DEEP Sound's
 * own player is paused before the session opens and never sees this audio, so
 * the mini player never surfaces it. A transient loss (a call, a navigation
 * prompt) is handled by ExoPlayer and resumed at the live edge here. A
 * *permanent* loss — the member chose to play something else — is respected:
 * the meditation stays quiet until they come back to DEEP, where it rejoins
 * the live edge. iOS would play over them; on Android that fights the system.
 *
 * Headphones pulled mid-meditation keep playing through the speaker, as iOS's
 * layer-3 recovery does — the sit is not paused by a cable.
 *
 * Owned per visit; [GlobalPauseService] holds the process up while it plays.
 */
@OptIn(UnstableApi::class)
class GlobalPauseAudioPlayer(
  private val context: Context,
  private val mediaClient: OkHttpClient,
) : GlobalPauseAudioPlaying {

  private val _isMeditating = MutableStateFlow(false)
  override val isMeditating: StateFlow<Boolean> = _isMeditating.asStateFlow()

  private val _elapsed = MutableStateFlow(Duration.ZERO)
  override val meditationElapsed: StateFlow<Duration> = _elapsed.asStateFlow()

  override var meditationOffsetProvider: (() -> Duration)? = null

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
  private var player: ExoPlayer? = null
  private var duration: Duration = Duration.ZERO
  private var ticker: Job? = null
  private var recovery: Job? = null

  /** True once the member gave the audio to something else; rejoined on return. */
  private var yieldedFocus = false

  /** A seek of our own is settling; its buffering is not a stall. */
  private var seekSettling = false

  /** Playback starved mid-stream, and is waiting for data. */
  private var stalled = false

  private val foreground = object : DefaultLifecycleObserver {
    override fun onStart(owner: LifecycleOwner) {
      if (_isMeditating.value && (yieldedFocus || player?.isPlaying != true)) recoverToLiveEdge()
    }
  }

  private val listener = object : Player.Listener {
    override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
      if (!playWhenReady && reason == Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_FOCUS_LOSS) {
        yieldedFocus = true
      }
    }

    override fun onPlaybackSuppressionReasonChanged(reason: Int) {
      // A call or a prompt is over: the stream moved on while we were quiet. But
      // a transient loss turning permanent clears the suppression too, as it
      // drops playWhenReady — that is the member's choice, not an all-clear.
      if (reason != Player.PLAYBACK_SUPPRESSION_REASON_NONE) return
      if (player?.playWhenReady != true || yieldedFocus) return
      recoverToLiveEdge()
    }

    override fun onPlaybackStateChanged(state: Int) {
      when (state) {
        Player.STATE_ENDED -> _elapsed.value = duration
        // An error's idle is the error listener's to recover.
        Player.STATE_IDLE -> Unit
        Player.STATE_BUFFERING -> if (!seekSettling && player?.playWhenReady == true) stalled = true
        Player.STATE_READY -> {
          seekSettling = false
          if (stalled) {
            stalled = false
            rejoinIfBehind()
          }
        }
      }
    }

    override fun onPlayerError(error: PlaybackException) {
      Log.w(TAG, "Meditation stream failed; rejoining the live edge", error)
      scheduleRecovery()
    }
  }

  override fun playMeditation(url: String, offset: Duration, duration: Duration) {
    stopMeditation()
    // A latecomer past the end gets silence — the session has moved on.
    if (offset >= duration) return

    this.duration = duration
    val exo = ExoPlayer.Builder(context)
      .setAudioAttributes(
        AudioAttributes.Builder()
          .setUsage(C.USAGE_MEDIA)
          .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
          .build(),
        /* handleAudioFocus = */ true,
      )
      .setWakeMode(C.WAKE_MODE_NETWORK)
      .setMediaSourceFactory(
        DefaultMediaSourceFactory(DefaultDataSource.Factory(context, OkHttpDataSource.Factory(mediaClient))),
      )
      .build()
    exo.addListener(listener)
    exo.setMediaItem(MediaItem.fromUri(url))
    exo.prepare()
    seekSettling = true
    stalled = false
    exo.seekTo(offset.toMillis())
    exo.playWhenReady = true
    player = exo
    // Registered before the meditation is marked live: registering replays the
    // current ON_START, which must not read as a return to the app.
    ProcessLifecycleOwner.get().lifecycle.addObserver(foreground)
    _elapsed.value = offset
    _isMeditating.value = true
    yieldedFocus = false

    GlobalPauseService.start(context)
    ticker = scope.launch {
      while (isActive) {
        delay(TICK_MILLIS)
        val exo = player ?: break
        _elapsed.value = Duration.ofMillis(exo.currentPosition)
        // Playing again means any seek of ours has settled, whatever states
        // it did or didn't pass through on the way.
        if (exo.isPlaying) seekSettling = false
      }
    }
  }

  override fun realignMeditation(offset: Duration) {
    val exo = player ?: return
    if (!_isMeditating.value) return
    if (offset >= duration) {
      stop()
      return
    }
    _elapsed.value = offset
    yieldedFocus = false
    if (exo.playbackState == Player.STATE_IDLE) exo.prepare()
    seekSettling = true
    stalled = false
    exo.seekTo(offset.toMillis())
    exo.playWhenReady = true
  }

  override fun stop() {
    stopMeditation()
  }

  private fun recoverToLiveEdge() {
    if (!_isMeditating.value) return
    val offset = meditationOffsetProvider?.invoke()
    if (offset != null) {
      realignMeditation(offset)
    } else {
      player?.playWhenReady = true
    }
  }

  /** A stall just cleared: rejoin the shared offset if the wait cost more than a blip. */
  private fun rejoinIfBehind() {
    val exo = player ?: return
    if (!_isMeditating.value) return
    val offset = meditationOffsetProvider?.invoke() ?: return
    if (offset.minusMillis(exo.currentPosition) > STALL_DRIFT) realignMeditation(offset)
  }

  /** Errors come in bursts on a dead network; one retry every few seconds. */
  private fun scheduleRecovery() {
    if (recovery?.isActive == true) return
    recovery = scope.launch {
      delay(RECOVERY_DELAY_MILLIS)
      // Given away for good, the meditation waits for the member's return.
      if (!yieldedFocus) recoverToLiveEdge()
    }
  }

  private fun stopMeditation() {
    ticker?.cancel()
    ticker = null
    recovery?.cancel()
    recovery = null
    ProcessLifecycleOwner.get().lifecycle.removeObserver(foreground)
    player?.let {
      it.removeListener(listener)
      it.release()
    }
    player = null
    seekSettling = false
    stalled = false
    if (_isMeditating.value) GlobalPauseService.stop(context)
    _isMeditating.value = false
    _elapsed.value = Duration.ZERO
    duration = Duration.ZERO
  }

  /** Releases everything, for good — the visit is over. */
  fun release() {
    stopMeditation()
    scope.cancel()
  }

  private companion object {
    const val TAG = "GlobalPauseAudio"
    const val TICK_MILLIS = 500L
    const val RECOVERY_DELAY_MILLIS = 3_000L

    /** Behind the shared offset by more than this after a stall, the stream
     * jumps to it; less is a blip not worth an audible skip. */
    val STALL_DRIFT: Duration = Duration.ofSeconds(2)
  }
}
