package io.appbeyond.freelance.deep.feature.globalpause.audio

import android.content.Context
import android.util.Log
import androidx.annotation.OptIn
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
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
import io.appbeyond.freelance.deep.feature.globalpause.store.LoungeRadio
import io.appbeyond.freelance.deep.feature.globalpause.store.LoungeRadioPlaying
import io.appbeyond.freelance.deep.feature.globalpause.store.LoungeRadioState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import java.time.Duration

/**
 * The real lounge radio: a bare [ExoPlayer] streaming the lobby track from the
 * backend's `/media/` route, joined at whatever offset the synced clock says
 * the set has reached.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Audio/LoungeRadioPlayer.swift.
 * Recovery keeps it a broadcast rather than a recording: whatever silenced it
 * — a call, a stall, an error, the member stepping out of DEEP — it comes back
 * at the live edge through [liveOffsetProvider], so they land where the room
 * actually is, not where they left it. Mute is the same promise: the set runs
 * on underneath, and unmuting rejoins it live.
 *
 * The set plays out once and is not looped: its end is the set's end, and the
 * session's boundary timer takes the badge down at the same instant.
 *
 * **Audio focus** as [GlobalPauseAudioPlayer] takes it: on as it starts, which
 * quiets anything else; a transient loss is ExoPlayer's to pause and resumes
 * here at the live edge; a permanent loss — the member chose to play
 * something else — is respected until they come back to DEEP.
 *
 * **In the background it falls quiet.** iOS plays the set on behind a locked
 * phone, with the lock screen's play and pause wired to mute. Android would
 * need a foreground service and its notification to do the same, and a
 * lounge left playing from a pocket is the case the intro clip already
 * declines (the lounge's `FukuIntroVideo`). Coming back rejoins
 * the live edge, as the intro does. So no `MediaSession` either: there is no
 * lock-screen entry to wire.
 *
 * Owned out in `MainActivity`, not by the lounge — the lounge stays composed
 * under a Global Pause, so the session has to be able to silence it.
 */
@OptIn(UnstableApi::class)
class LoungeRadioPlayer(
  private val context: Context,
  private val mediaClient: OkHttpClient,
) : LoungeRadioPlaying {

  private val _state = MutableStateFlow<LoungeRadioState>(LoungeRadioState.Off)
  override val state: StateFlow<LoungeRadioState> = _state.asStateFlow()

  override var liveOffsetProvider: (() -> Duration?)? = null

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
  private var player: ExoPlayer? = null
  private var currentUrl: String? = null
  private var recovery: Job? = null

  /** DEEP is out of sight; the set waits for the member to come back. */
  private var inBackground = false

  /** A seek of our own is settling; its buffering is not a stall. */
  private var seekSettling = false

  /** Playback starved mid-stream, and is waiting for data. */
  private var stalled = false

  private val isMuted: Boolean
    get() = (_state.value as? LoungeRadioState.OnAir)?.isMuted ?: false

  private val foreground = object : DefaultLifecycleObserver {
    override fun onStart(owner: LifecycleOwner) {
      if (!inBackground) return
      inBackground = false
      recoverToLiveEdge()
    }

    override fun onStop(owner: LifecycleOwner) {
      inBackground = true
      player?.playWhenReady = false
    }
  }

  private val listener = object : Player.Listener {
    override fun onPlaybackSuppressionReasonChanged(reason: Int) {
      // A call or a prompt is over: the set moved on while we were quiet.
      if (reason == Player.PLAYBACK_SUPPRESSION_REASON_NONE) recoverToLiveEdge()
    }

    override fun onPlaybackStateChanged(state: Int) {
      when (state) {
        // The set running out is the set ending. Released off the player's own
        // callback, and only if no fresh join has replaced it meanwhile.
        Player.STATE_ENDED -> {
          val ended = player
          scope.launch(Dispatchers.Main) { if (player === ended) stop() }
        }
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

    override fun onIsPlayingChanged(isPlaying: Boolean) {
      // Playing again means any seek of ours has settled, whatever states it
      // did or didn't pass through on the way.
      if (isPlaying) seekSettling = false
    }

    override fun onPlayerError(error: PlaybackException) {
      // iOS stops on a failed item; ExoPlayer also reports a dropped network
      // mid-set this way — what AVPlayer calls a stall — so retry at the live
      // edge, as the meditation does, until the set ends or the lounge leaves.
      Log.w(TAG, "Lounge track failed; rejoining the live edge", error)
      scheduleRecovery()
    }
  }

  override fun join(url: String, offset: Duration) {
    val playing = player
    val position = playing?.let { Duration.ofMillis(it.currentPosition) }
    if (_state.value is LoungeRadioState.OnAir && LoungeRadio.isAlreadyTuned(currentUrl, position, url, offset)) return

    val wasMuted = isMuted
    teardownPlayer()

    // Registered before anything plays: registering replays the current
    // ON_START, which must not read as a return to the app.
    val lifecycle = ProcessLifecycleOwner.get().lifecycle
    inBackground = !lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
    lifecycle.addObserver(foreground)

    val exo = ExoPlayer.Builder(context)
      .setAudioAttributes(
        AudioAttributes.Builder()
          .setUsage(C.USAGE_MEDIA)
          .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
          .build(),
        /* handleAudioFocus = */ true,
      )
      .setMediaSourceFactory(
        DefaultMediaSourceFactory(DefaultDataSource.Factory(context, OkHttpDataSource.Factory(mediaClient))),
      )
      .build()
    exo.addListener(listener)
    exo.volume = if (wasMuted) 0f else 1f
    exo.setMediaItem(MediaItem.fromUri(url))
    exo.prepare()
    seekSettling = true
    stalled = false
    exo.seekTo(offset.coerceAtLeast(Duration.ZERO).toMillis())
    exo.playWhenReady = !inBackground
    player = exo
    currentUrl = url
    _state.value = LoungeRadioState.OnAir(isMuted = wasMuted)
  }

  override fun setMuted(muted: Boolean) {
    if (_state.value !is LoungeRadioState.OnAir) return
    player?.volume = if (muted) 0f else 1f
    _state.value = LoungeRadioState.OnAir(isMuted = muted)
    // Unmuting rejoins the room rather than resuming a broadcast that has
    // moved on without us.
    if (!muted) recoverToLiveEdge()
  }

  override fun stop() {
    teardownPlayer()
    currentUrl = null
    _state.value = LoungeRadioState.Off
  }

  /**
   * Re-seeks to wherever the room has got to and plays on. A muted set stays
   * muted — it is still running, the member just isn't listening. A set that
   * has signed off while we were away stops instead.
   */
  private fun recoverToLiveEdge() {
    if (_state.value !is LoungeRadioState.OnAir || inBackground) return
    val exo = player ?: return
    val provider = liveOffsetProvider
    if (provider == null) {
      exo.playWhenReady = true
      return
    }
    val offset = provider() ?: return stop()
    realign(exo, offset)
  }

  private fun realign(exo: ExoPlayer, offset: Duration) {
    if (exo.playbackState == Player.STATE_IDLE) exo.prepare()
    seekSettling = true
    stalled = false
    exo.seekTo(offset.coerceAtLeast(Duration.ZERO).toMillis())
    exo.playWhenReady = true
  }

  /** A stall just cleared: rejoin the live edge if the wait cost more than a blip. */
  private fun rejoinIfBehind() {
    val exo = player ?: return
    if (_state.value !is LoungeRadioState.OnAir || inBackground) return
    val offset = liveOffsetProvider?.invoke() ?: return
    if (offset.minusMillis(exo.currentPosition) > STALL_DRIFT) realign(exo, offset)
  }

  /** Errors come in bursts on a dead network; one retry every few seconds. */
  private fun scheduleRecovery() {
    if (recovery?.isActive == true) return
    recovery = scope.launch {
      delay(RECOVERY_DELAY_MILLIS)
      recoverToLiveEdge()
    }
  }

  private fun teardownPlayer() {
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
    inBackground = false
  }

  /** Releases everything, for good — the activity is going. */
  fun release() {
    stop()
    scope.cancel()
  }

  private companion object {
    const val TAG = "LoungeRadio"
    const val RECOVERY_DELAY_MILLIS = 3_000L

    /** Behind the live edge by more than this after a stall, the set jumps to
     * it; less is a blip not worth an audible skip. */
    val STALL_DRIFT: Duration = Duration.ofSeconds(2)
  }
}
