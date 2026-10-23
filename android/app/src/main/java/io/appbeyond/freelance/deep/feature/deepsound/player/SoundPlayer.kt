package io.appbeyond.freelance.deep.feature.deepsound.player

import android.content.ComponentName
import android.content.Context
import android.util.Log
import androidx.annotation.MainThread
import androidx.core.content.ContextCompat
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundPlayback
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueue
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import java.util.concurrent.CancellationException
import java.util.concurrent.ExecutionException

/**
 * The app's one sound player: the queue the UI reads, driving [DeepSoundService]'s
 * player through a `MediaController`.
 *
 * The Android half of `StreamingSoundPlayer.swift` — the half that owns state.
 * iOS holds the `AVPlayer` directly; here the audio lives in a service so it
 * survives the activity, and this class is one controller of it among several
 * (the notification, the lock screen, a headset). It stays the source of truth
 * for the queue — the session only ever holds a copy, index for index — and it
 * mirrors back what the player really did, so a pause from the lock screen or a
 * track ending in the background shows up here.
 *
 * Process-lifetime, one instance, built in `AppDependencies`. Main-thread only:
 * `MediaController` is bound to the looper it was built on.
 *
 * **Connecting.** The controller is built on first need, never at launch, so an
 * app that never plays a sound never starts the service. Only the calls that
 * start audio — [play], and [togglePlayPause] into playing — connect. The rest
 * act on a live connection, queue behind one already in flight, or otherwise
 * just move this class's state, which the next connection pushes to the
 * session. Commands issued while a connection is in flight run in order once it
 * lands.
 *
 * **Optimistic.** Every command updates [playback] and [elapsed] at once rather
 * than waiting for the round trip through the session, so the UI answers a tap
 * in the same frame, as the iOS players do. The mirror then confirms or
 * corrects it.
 *
 * **Losing the service.** If the connection drops — the service was killed, or
 * crashed — the queue is kept and marked for resync: the next connection pushes
 * it back at the same track and position, paused.
 */
@MainThread
class SoundPlayer(context: Context) : SoundPlaying {

  private val context = context.applicationContext
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

  private val _playback = MutableStateFlow(SoundPlayback.Idle)
  override val playback: StateFlow<SoundPlayback> = _playback.asStateFlow()

  private val _elapsed = MutableStateFlow(0.0)
  override val elapsed: StateFlow<Double> = _elapsed.asStateFlow()

  private var controller: MediaController? = null
  private var connecting: ListenableFuture<MediaController>? = null

  /** Commands waiting on [connecting], in the order they were issued. */
  private val pending = ArrayDeque<(MediaController) -> Unit>()

  /**
   * The session's queue can no longer be trusted to be ours — the connection
   * dropped, or the mirror saw a track it did not expect. The next command that
   * reaches the session pushes the whole queue first.
   */
  private var needsResync = false

  init {
    tickElapsed()
  }

  // MARK: Transport

  override fun play(entries: List<SoundQueueEntry>, startIndex: Int) {
    if (entries.isEmpty()) {
      clear()
      return
    }
    val index = SoundQueue.clampStart(startIndex, entries.size)
    // A track with no audio loads paused, as iOS's `loadCurrent` does with a
    // nil `audioURL`; the service would pause it anyway, a frame later.
    val playable = entries[index].track.audioUrl != null
    _playback.value = _playback.value.copy(entries = entries, index = index, isPlaying = playable)
    _elapsed.value = 0.0
    // The whole queue goes out below, so an older resync is moot.
    needsResync = false

    withController { controller ->
      controller.setMediaItems(entries.map { it.toMediaItem() }, index, 0L)
      if (controller.playbackState == Player.STATE_IDLE) controller.prepare()
      controller.playWhenReady = playable
    }
  }

  override fun togglePlayPause() {
    val state = _playback.value
    if (!state.hasTrack) return
    if (state.isPlaying) {
      pauseNow()
      return
    }
    // Unlike iOS, which flips the flag and lets `AVPlayer` play nothing, a
    // track with no audio stays paused: the service would refuse it, and the
    // play button would flicker on and off again.
    if (!state.isCurrentPlayable) return
    _playback.value = state.copy(isPlaying = true)
    withController { controller ->
      // After an error the player sits idle; play() alone would do nothing.
      if (controller.playbackState == Player.STATE_IDLE) controller.prepare()
      controller.play()
    }
  }

  /** Never connects: a player nobody has started has nothing to pause. */
  override fun pause() {
    if (_playback.value.isPlaying) pauseNow()
  }

  override fun next() {
    val state = _playback.value
    if (!state.hasTrack) return
    val index = SoundQueue.nextIndex(state.index, state.entries.size)
    moveTo(state, index)
  }

  override fun previous() {
    val state = _playback.value
    if (!state.hasTrack) return
    // Decide on the player's position, not the last tick — nothing ticks while
    // no one is watching, and a stale elapsed would restart when it should
    // step back.
    syncElapsed()
    when (val move = SoundQueue.previous(_elapsed.value, state.index, state.entries.size)) {
      SoundQueue.Previous.Restart -> seekToSeconds(0.0)
      is SoundQueue.Previous.GoTo -> moveTo(state, move.index)
    }
  }

  override fun seek(toProgress: Double) {
    val state = _playback.value
    if (!state.hasTrack) return
    seekToSeconds(SoundQueue.seekTarget(toProgress, state.duration))
  }

  override fun setVolume(volume: Double) {
    val clamped = volume.coerceIn(0.0, 1.0)
    _playback.value = _playback.value.copy(volume = clamped)
    // Re-applied on every connection, so there is nothing to queue.
    controller?.takeIf { it.isConnected }?.volume = clamped.toFloat()
  }

  /**
   * Stops everything and forgets the queue: releases the controller (and with
   * it the service, once nothing else is bound), and returns to
   * [SoundPlayback.Idle].
   *
   * Not on [SoundPlaying] — no screen calls it. `AppDependencies` does, when the
   * member signs out, so the next person to sign in on this phone does not find
   * the last one's track in the mini player or on the lock screen.
   */
  fun clear() {
    pending.clear()
    connecting?.let { MediaController.releaseFuture(it) }
    connecting = null
    controller?.let {
      // Detach first: the release below reports a disconnect, and this is not
      // one to recover from.
      controller = null
      it.removeListener(playerListener)
      it.stop()
      it.clearMediaItems()
      it.release()
    }
    needsResync = false
    _playback.value = SoundPlayback.Idle
    _elapsed.value = 0.0
  }

  private fun pauseNow() {
    _playback.value = _playback.value.copy(isPlaying = false)
    syncElapsed()
    whenConnected { it.pause() }
  }

  /** To another track: at its start, playing if the queue was playing. */
  private fun moveTo(state: SoundPlayback, index: Int) {
    val playing = state.isPlaying && state.entries[index].track.audioUrl != null
    _playback.value = state.copy(index = index, isPlaying = playing)
    _elapsed.value = 0.0
    whenConnected { controller ->
      controller.seekTo(index, 0L)
      controller.playWhenReady = playing
    }
  }

  private fun seekToSeconds(seconds: Double) {
    _elapsed.value = seconds
    whenConnected { it.seekTo((seconds * 1_000).toLong()) }
  }

  // MARK: Connection

  /** Runs [command] on the session, connecting first if need be. */
  private fun withController(command: (MediaController) -> Unit) {
    val live = controller
    if (live != null && live.isConnected) {
      send(live, command)
      return
    }
    pending.addLast(command)
    connect()
  }

  /**
   * Runs [command] on a live session, or behind one already connecting.
   * Otherwise drops it: the state it followed is already in [playback] and
   * [elapsed], and whichever connection comes next carries it across.
   */
  private fun whenConnected(command: (MediaController) -> Unit) {
    val live = controller
    when {
      live != null && live.isConnected -> send(live, command)
      connecting != null -> pending.addLast(command)
    }
  }

  private fun send(controller: MediaController, command: (MediaController) -> Unit) {
    if (needsResync) pushQueue(controller)
    command(controller)
  }

  private fun connect() {
    if (connecting != null) return
    val token = SessionToken(context, ComponentName(context, DeepSoundService::class.java))
    val future = MediaController.Builder(context, token)
      .setListener(controllerListener)
      .buildAsync()
    connecting = future
    future.addListener(
      {
        // Released by clear() while in flight: it has already forgotten us.
        if (connecting !== future) return@addListener
        connecting = null
        val connected = try {
          future.get()
        } catch (failed: ExecutionException) {
          Log.w(TAG, "Could not connect to the sound session.", failed.cause ?: failed)
          null
        } catch (cancelled: CancellationException) {
          null
        }
        if (connected == null) {
          // Nothing will ever run them. What they did to the state stands, and
          // the next connection carries it across.
          pending.clear()
          needsResync = true
          _playback.value = _playback.value.copy(isPlaying = false)
          return@addListener
        }
        onConnected(connected)
      },
      ContextCompat.getMainExecutor(context),
    )
  }

  private fun onConnected(connected: MediaController) {
    controller = connected
    connected.addListener(playerListener)
    connected.volume = _playback.value.volume.toFloat()
    if (needsResync) pushQueue(connected)
    while (pending.isNotEmpty()) pending.removeFirst()(connected)
    mirror(connected)
  }

  /**
   * Puts this class's queue back on the session, at the track and position it
   * stands at. After a lost connection that is paused — the drop already said
   * so — and a command queued behind the push decides whether it plays.
   */
  private fun pushQueue(controller: MediaController) {
    needsResync = false
    val state = _playback.value
    if (!state.hasTrack) return
    controller.setMediaItems(
      state.entries.map { it.toMediaItem() },
      state.index,
      (_elapsed.value * 1_000).toLong(),
    )
    controller.prepare()
    controller.playWhenReady = state.isPlaying && state.isCurrentPlayable
  }

  private val controllerListener = object : MediaController.Listener {
    override fun onDisconnected(controller: MediaController) {
      if (controller !== this@SoundPlayer.controller) return
      this@SoundPlayer.controller = null
      controller.removeListener(playerListener)
      controller.release()
      needsResync = true
      _playback.value = _playback.value.copy(isPlaying = false)
    }
  }

  // MARK: Mirror

  private val playerListener = object : Player.Listener {
    override fun onEvents(player: Player, events: Player.Events) {
      mirror(player, events)
    }
  }

  /**
   * Folds what the session's player actually did back into [playback].
   *
   * The index is taken only when the item there is the track this queue has at
   * that index. Anything else — a queue the session lost, or one caught
   * mid-replacement — marks the queue for resync rather than pointing the UI at
   * the wrong track.
   *
   * "Playing" means *wants to play and is allowed to*, not ExoPlayer's
   * `isPlaying`: that one drops to false for every buffering stall, and the play
   * button would flicker with the network. A focus loss (a phone call) does
   * suppress it, and an error — which leaves the player idle — ends it.
   */
  private fun mirror(player: Player, events: Player.Events? = null) {
    val state = _playback.value
    if (!state.hasTrack) return

    val at = player.currentMediaItemIndex
    val expected = state.entries.getOrNull(at)?.track?.id
    val matches = expected != null && player.currentMediaItem?.mediaId == expected
    if (!matches) needsResync = true

    val isPlaying = player.playWhenReady &&
      player.playbackSuppressionReason == Player.PLAYBACK_SUPPRESSION_REASON_NONE &&
      player.playbackState != Player.STATE_IDLE
    val index = if (matches) at else state.index
    _playback.value = state.copy(index = index, isPlaying = isPlaying)

    val moved = events == null || events.containsAny(
      Player.EVENT_MEDIA_ITEM_TRANSITION,
      Player.EVENT_POSITION_DISCONTINUITY,
      Player.EVENT_PLAY_WHEN_READY_CHANGED,
      Player.EVENT_PLAYBACK_STATE_CHANGED,
    )
    if (matches && moved) _elapsed.value = player.currentPosition / 1_000.0
  }

  // MARK: Elapsed

  /** Reads the position off a live, in-step session. */
  private fun syncElapsed() {
    val live = controller ?: return
    if (!live.isConnected || needsResync) return
    _elapsed.value = live.currentPosition / 1_000.0
  }

  /**
   * Polls the position every 250ms, but only while the queue is playing and
   * something collects [elapsed]. A `MediaController` has no position
   * callback — iOS's periodic time observer — and polling with nobody watching
   * would wake the main thread four times a second for as long as the music
   * plays with the screen off.
   */
  private fun tickElapsed() {
    scope.launch {
      combine(
        _elapsed.subscriptionCount.map { it > 0 },
        _playback.map { it.isPlaying },
      ) { watched, playing -> watched && playing }
        .distinctUntilChanged()
        .collectLatest { ticking ->
          if (!ticking) return@collectLatest
          // Ends when collectLatest cancels it for the next change.
          while (true) {
            syncElapsed()
            delay(TICK_MILLIS)
          }
        }
    }
  }

  private companion object {
    const val TAG = "SoundPlayer"
    const val TICK_MILLIS = 250L
  }
}
