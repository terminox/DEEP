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
import io.appbeyond.freelance.deep.feature.deepsound.model.RepeatMode
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundPlayback
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueue
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import io.appbeyond.freelance.deep.shared.persistence.BlobStoring
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
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
import kotlin.random.Random

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
 *
 * **Repeat and Shuffle.** The queue rules are `SoundQueue`'s, here for the
 * optimistic state and in the service's `SoundQueuePlayer` for what the audio
 * actually does — including the moves no button made (a track ending, a stream
 * failing) and the ones a foreign controller did. This class sends its own
 * moves as explicit seeks, so the two cannot disagree about where a skip
 * lands. There is one play order: this class deals every shuffle it starts
 * and hands the order to the service ahead of the queue or the Shuffle it
 * belongs to (as the playlist's metadata, which rides the same ordered
 * command queue), so a skip worked out before the session connected follows
 * the order the audio will. A shuffle another controller starts is dealt by
 * the service and read back the same way. Repeat is kept in [settings]
 * between launches, as iOS keeps it in `UserDefaults`, every choice written
 * in turn so the last one made is the one kept; Shuffle lasts the session.
 *
 * @param settings where the Repeat choice is kept — `deep.sound` in
 *   production.
 * @param hasPremium the listener's DEEP Premium answer at the moment a queue
 *   is loaded — what decides which tracks may join it (`SoundQueue.playable`).
 */
@MainThread
class SoundPlayer(
  context: Context,
  private val settings: BlobStoring,
  private val hasPremium: () -> Boolean = { false },
) : SoundPlaying {

  private val context = context.applicationContext
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

  /** Deals every shuffle this class starts — the one order the service plays too. */
  private val random = Random.Default

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

  /**
   * Whether Repeat has been set this launch — by the listener here, or from
   * another controller — so the stored choice, read a moment after launch,
   * never undoes a newer one.
   */
  private var repeatChosen = false

  /**
   * Repeat choices waiting to be written, newest only. One writer drains it,
   * each write finishing before the next begins: separate launches would race
   * on the IO pool, and a quick All → One could land One, then All.
   */
  private val repeatToSave = Channel<RepeatMode>(Channel.CONFLATED)

  init {
    tickElapsed()
    restoreRepeatMode()
    saveRepeatModes()
  }

  // MARK: Transport

  override fun play(entries: List<SoundQueueEntry>, startIndex: Int?, shuffled: Boolean) {
    if (entries.isEmpty()) {
      clear()
      return
    }
    if (isPlaybackHeld) return
    // DEEP Premium tracks this listener is locked out of — and premium audio
    // the server withheld — never join the queue, so neither this class nor
    // the lock screen can advance onto one; nor, beside tracks that have
    // audio, does one without. A queue with nothing that can start plays
    // nothing, and leaves what was loaded alone.
    val start = SoundQueue.playable(entries, startIndex, hasPremium()) ?: return
    load(_playback.value.queue.replacing(start.entries, start.index, shuffled, random))
  }

  private fun load(queue: SoundQueue<SoundQueueEntry>) {
    val index = queue.currentIndex ?: return
    // A track with no audio loads paused, as iOS's `loadCurrent` does with a
    // nil `audioURL`; the service would pause it anyway, a frame later.
    val playable = queue.current?.track?.audioUrl != null
    _playback.value = _playback.value.copy(queue = queue, isPlaying = playable)
    _elapsed.value = 0.0
    // The whole queue goes out below, so an older resync is moot.
    needsResync = false

    withController { controller ->
      // Modes first: the service deals a shuffle as the new queue lands.
      applyModes(controller, queue)
      controller.setMediaItems(queue.entries.map { it.toMediaItem() }, index, 0L)
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
    // play button would flicker on and off again. Held, nothing starts at all.
    if (!state.isCurrentPlayable || isPlaybackHeld) return
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
    val (queue, carriesOn) = state.queue.skipForward()
    moveTo(state, queue, playing = state.isPlaying && carriesOn)
  }

  override fun previous() {
    val state = _playback.value
    if (!state.hasTrack) return
    // Decide on the player's position, not the last tick — nothing ticks while
    // no one is watching, and a stale elapsed would restart when it should
    // step back.
    syncElapsed()
    if (_elapsed.value <= SoundQueue.RESTART_THRESHOLD_SECONDS) {
      val (queue, moved) = state.queue.skipBack()
      if (moved) {
        moveTo(state, queue, playing = state.isPlaying)
        return
      }
    }
    seekToSeconds(0.0)
  }

  override fun setRepeatMode(mode: RepeatMode) {
    repeatChosen = true
    if (mode == _playback.value.repeatMode) return
    adoptRepeatMode(mode)
    persist(mode)
  }

  override fun setShuffled(shuffled: Boolean) {
    val state = _playback.value
    if (shuffled == state.isShuffled) return
    val queue = state.queue.withShuffle(shuffled, random)
    _playback.value = state.copy(queue = queue)
    // Not pushed without a session: the next queue pushed carries it. The
    // order goes first, so the service shuffles by this deal, not one of its own.
    whenConnected { controller ->
      controller.playlistMetadata = playOrderMetadata(queue.order)
      controller.shuffleModeEnabled = shuffled
    }
  }

  override fun seek(toProgress: Double) {
    val state = _playback.value
    if (!state.hasTrack) return
    seekToSeconds(SoundQueue.seekTarget(toProgress, state.duration))
  }

  private val _playbackHeld = MutableStateFlow(false)

  /**
   * The hold, for [DeepSoundService]: while it is set the service takes play
   * away from the notification, the lock screen and a headset — they reach the
   * service's player directly, never this class — and refuses it if a play
   * arrives anyway.
   */
  val playbackHeld: StateFlow<Boolean> = _playbackHeld.asStateFlow()

  override val isPlaybackHeld: Boolean get() = _playbackHeld.value

  override fun holdPlayback(held: Boolean) {
    // Paused first, so the pause still goes out on a session whose play
    // command the hold is about to take away.
    if (held) pause()
    _playbackHeld.value = held
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
   * [SoundPlayback.Idle] — keeping Repeat, which belongs to the phone rather
   * than the account, as iOS's `UserDefaults` key does.
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
    val repeatMode = _playback.value.repeatMode
    _playback.value = SoundPlayback.Idle.copy(queue = SoundPlayback.Idle.queue.withRepeatMode(repeatMode))
    _elapsed.value = 0.0
  }

  private fun pauseNow() {
    _playback.value = _playback.value.copy(isPlaying = false)
    syncElapsed()
    whenConnected { it.pause() }
  }

  /**
   * To where [queue] now stands: the start of its current track, [playing] if
   * that track has audio. Sent as an explicit seek, not a skip, so the service
   * lands exactly where this class already shows.
   */
  private fun moveTo(state: SoundPlayback, queue: SoundQueue<SoundQueueEntry>, playing: Boolean) {
    val index = queue.currentIndex ?: return
    val play = playing && queue.current?.track?.audioUrl != null
    _playback.value = state.copy(queue = queue, isPlaying = play)
    _elapsed.value = 0.0
    whenConnected { controller ->
      controller.seekTo(index, 0L)
      // Stopped after failing streams, the player sits idle; a seek alone
      // would not load the track it lands on.
      if (play && controller.playbackState == Player.STATE_IDLE) controller.prepare()
      controller.playWhenReady = play
    }
  }

  /** Puts [mode] in the state and on the session, without persisting it. */
  private fun adoptRepeatMode(mode: RepeatMode) {
    val state = _playback.value
    _playback.value = state.copy(queue = state.queue.withRepeatMode(mode))
    // Not pushed without a session: the next queue pushed carries it.
    whenConnected { it.repeatMode = mode.playerMode }
  }

  /**
   * Repeat, Shuffle and the play order [queue] will be pushed with — sent just
   * ahead of its `setMediaItems`, which takes the order. The order goes last:
   * Shuffle turning on before the new queue lands shuffles the old one, and
   * must not take the order dealt for this one.
   */
  private fun applyModes(controller: MediaController, queue: SoundQueue<SoundQueueEntry>) {
    controller.repeatMode = queue.repeatMode.playerMode
    controller.shuffleModeEnabled = queue.isShuffled
    controller.playlistMetadata = playOrderMetadata(queue.order)
  }

  // MARK: Repeat, between launches

  /** Reads the stored Repeat choice back, unless one was made in the meantime. */
  private fun restoreRepeatMode() {
    scope.launch {
      val stored = try {
        RepeatMode.of(settings.read())
      } catch (cancelled: CancellationException) {
        throw cancelled
      } catch (unreadable: Exception) {
        Log.w(TAG, "Could not read the Repeat setting.", unreadable)
        null
      }
      if (stored == null || repeatChosen) return@launch
      repeatChosen = true
      if (stored != _playback.value.repeatMode) adoptRepeatMode(stored)
    }
  }

  private fun persist(mode: RepeatMode) {
    repeatToSave.trySend(mode)
  }

  private fun saveRepeatModes() {
    scope.launch {
      for (mode in repeatToSave) {
        try {
          settings.write(mode.raw)
        } catch (cancelled: CancellationException) {
          throw cancelled
        } catch (failed: Exception) {
          // The choice stands for this launch; the next one starts from off.
          Log.w(TAG, "Could not save the Repeat setting.", failed)
        }
      }
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
    // A shuffle is dealt afresh from the current track: the old deal died with
    // the session that held it.
    applyModes(controller, state.queue)
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
   * the wrong track. With it come the session's Repeat and Shuffle, and the
   * play order it dealt, so a lock screen's change or a service's shuffle reads
   * here as if made here; a Repeat set elsewhere is saved as the listener's
   * choice.
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
    val queue = if (matches) adopt(state.queue, player, at) else state.queue
    if (queue.repeatMode != state.repeatMode) {
      repeatChosen = true
      persist(queue.repeatMode)
    }
    _playback.value = state.copy(queue = queue, isPlaying = isPlaying)

    val moved = events == null || events.containsAny(
      Player.EVENT_MEDIA_ITEM_TRANSITION,
      Player.EVENT_POSITION_DISCONTINUITY,
      Player.EVENT_PLAY_WHEN_READY_CHANGED,
      Player.EVENT_PLAYBACK_STATE_CHANGED,
    )
    if (matches && moved) _elapsed.value = player.currentPosition / 1_000.0
  }

  /**
   * [queue] as the session holds it, standing on [at]. A timeline caught
   * mid-replacement has no play order over these entries yet; the queue then
   * keeps its own order, moved to [at].
   */
  private fun adopt(queue: SoundQueue<SoundQueueEntry>, player: Player, at: Int): SoundQueue<SoundQueueEntry> {
    val repeatMode = repeatModeOf(player.repeatMode)
    val shuffled = player.shuffleModeEnabled
    // The published order first: the controller holds the one this class just
    // sent until the session has taken it, where its timeline's shuffle would
    // still be the old one.
    val published = player.playlistMetadata.playOrder()?.takeIf { shuffled }
    return published?.let { queue.adopting(it, at, repeatMode, shuffled) }
      ?: queue.adopting(player.currentTimeline.playOrder(shuffled), at, repeatMode, shuffled)
      ?: queue.adopting(queue.order, at, repeatMode, shuffled)
      ?: queue
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
