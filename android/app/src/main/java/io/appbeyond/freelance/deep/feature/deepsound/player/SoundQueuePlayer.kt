@file:OptIn(UnstableApi::class)

package io.appbeyond.freelance.deep.feature.deepsound.player

import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.ForwardingSimpleBasePlayer
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Timeline
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.ShuffleOrder
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import io.appbeyond.freelance.deep.feature.deepsound.model.RepeatMode
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueue
import kotlin.random.Random

/**
 * The service's player as the queue rules shape it — iOS `SoundQueue`'s rules,
 * applied for every controller at once.
 *
 * **Where the queue lives.** ExoPlayer keeps the queue in list order, index for
 * index with [SoundPlayer]'s, and its own Repeat and Shuffle carry the play
 * order: its repeat mode is the listener's, and a shuffle is an exact
 * `ShuffleOrder` this class deals — the current track first, the rest in a
 * random order after it — rather than ExoPlayer's own. That keeps everything a
 * track ending can need inside ExoPlayer: the next track is already buffered,
 * Repeat One loops without a gap, and a playlist runs on with the screen off
 * and no app code awake at the boundary, as iOS's pre-loaded `AVQueuePlayer`
 * item does.
 *
 * ExoPlayer's own rules differ from iOS's in four places, and those are what
 * this class answers, each by the same [SoundQueue] the app and its tests use:
 * - **Next** always moves on — Repeat One included — and wraps from the last
 *   track to the first, playing on after the wrap only in Repeat All. ExoPlayer
 *   reads Repeat One as off for a skip and has no next at the end at all.
 * - **Previous** follows the same queue (ExoPlayer's already agrees; answered
 *   here so the rule lives once).
 * - **The end of an unrepeated queue** rests on its first track, paused, where
 *   ExoPlayer would sit ended on the last.
 * - **A stream that fails** moves on to the next track — past Repeat One, which
 *   would only fail again — where ExoPlayer stops dead. A run of failures as
 *   long as the queue means nothing can play, and it stops.
 *
 * Next and Previous stay available whenever there is a queue, so the
 * notification and the lock screen keep both buttons at either end of it, as
 * iOS's do.
 *
 * @param onTrackFinished told when a track plays through to its natural end —
 *   the listen report. Skips, seeks and failures never call it.
 */
class SoundQueuePlayer(
  private val exo: ExoPlayer,
  private val onTrackFinished: (MediaItem) -> Unit,
  private val random: Random = Random.Default,
) : ForwardingSimpleBasePlayer(exo) {

  /** Tracks in a row that failed to load — iOS's `consecutiveFailures`. */
  private var consecutiveFailures = 0

  // MARK: Transport

  /**
   * Every seek, with the command that asked for it. The skips are answered
   * here, whatever index ExoPlayer's rules imply (none, at the end of an
   * unrepeated queue); every other seek passes through.
   */
  override fun handleSeek(mediaItemIndex: Int, positionMs: Long, seekCommand: Int): ListenableFuture<*> {
    when (seekCommand) {
      Player.COMMAND_SEEK_TO_NEXT, Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM -> skipForward()
      Player.COMMAND_SEEK_TO_PREVIOUS -> skipBack(restartsPastThreshold = true)
      Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM -> skipBack(restartsPastThreshold = false)
      else -> return super.handleSeek(mediaItemIndex, positionMs, seekCommand)
    }
    return Futures.immediateVoidFuture()
  }

  override fun handleSetShuffleModeEnabled(shuffleModeEnabled: Boolean): ListenableFuture<*> {
    if (shuffleModeEnabled && !exo.shuffleModeEnabled) dealFrom(exo.currentMediaItemIndex)
    return super.handleSetShuffleModeEnabled(shuffleModeEnabled)
  }

  /** A new queue: a fresh run of failures, and — shuffled — a fresh deal from its start. */
  override fun handleSetMediaItems(
    mediaItems: List<MediaItem>,
    startIndex: Int,
    startPositionMs: Long,
  ): ListenableFuture<*> {
    val result = super.handleSetMediaItems(mediaItems, startIndex, startPositionMs)
    consecutiveFailures = 0
    if (exo.shuffleModeEnabled) dealFrom(exo.currentMediaItemIndex)
    return result
  }

  private fun skipForward() {
    val (queue, carriesOn) = queue()?.skipForward() ?: return
    // Paused before the seek, so not a frame of the wrapped-to track plays.
    if (!carriesOn) exo.playWhenReady = false
    exo.seekTo(queue.currentIndex ?: return, 0L)
  }

  /**
   * Back a track while the current one is in its first seconds — or always,
   * for [restartsPastThreshold] false — and otherwise, or with nowhere to go,
   * back to the start of this one.
   */
  private fun skipBack(restartsPastThreshold: Boolean) {
    val queue = queue() ?: return
    val early = exo.currentPosition <= SoundQueue.RESTART_THRESHOLD_SECONDS * 1_000
    if (!restartsPastThreshold || early) {
      val (previous, moved) = queue.skipBack()
      val index = previous.currentIndex
      if (moved && index != null) {
        exo.seekTo(index, 0L)
        return
      }
    }
    exo.seekTo(exo.currentMediaItemIndex, 0L)
  }

  // MARK: What ExoPlayer does on its own

  private val rules = object : Player.Listener {

    /**
     * An auto-transition is the one discontinuity that means "played to the
     * end" — iOS's `AVPlayerItemDidPlayToEndTime`. It fires for a track moving
     * on and for Repeat One looping it; seeks and skips arrive with other
     * reasons.
     */
    override fun onPositionDiscontinuity(
      oldPosition: Player.PositionInfo,
      newPosition: Player.PositionInfo,
      reason: Int,
    ) {
      if (reason != Player.DISCONTINUITY_REASON_AUTO_TRANSITION) return
      consecutiveFailures = 0
      oldPosition.mediaItem?.let(onTrackFinished)
    }

    /** The last track of an unrepeated queue ended: rest on the first, paused. */
    override fun onPlaybackStateChanged(playbackState: Int) {
      if (playbackState != Player.STATE_ENDED) return
      consecutiveFailures = 0
      exo.currentMediaItem?.let(onTrackFinished)
      val (queue, carriesOn) = queue()?.advanceAfterEnd() ?: return
      if (!carriesOn) exo.playWhenReady = false
      exo.seekTo(queue.currentIndex ?: return, 0L)
    }

    /**
     * The current track could not play. The player is idle with the error;
     * it moves on and loads afresh, playing if it was — or, once every track
     * has failed in a row or an unrepeated queue runs out, rests paused and
     * idle. Idle, not prepared: a fresh load of a track that just failed would
     * only fail again, round and round. A later play prepares it.
     */
    override fun onPlayerError(error: PlaybackException) {
      val queue = queue() ?: return
      val wasPlaying = exo.playWhenReady
      consecutiveFailures += 1
      if (consecutiveFailures < queue.entries.size) {
        val (next, movedOn) = queue.skipUnplayable()
        val index = next.currentIndex ?: return
        if (movedOn) {
          exo.seekTo(index, 0L)
          exo.prepare()
          exo.playWhenReady = wasPlaying
          return
        }
        consecutiveFailures = 0
        exo.playWhenReady = false
        exo.seekTo(index, 0L)
        return
      }
      consecutiveFailures = 0
      exo.playWhenReady = false
      exo.seekTo(exo.currentMediaItemIndex, 0L)
    }
  }

  // Below the listener it adds: properties initialise in the order they are written.
  init {
    exo.addListener(rules)
  }

  // MARK: The queue

  /** The queue as the player holds it right now; null when it holds none. */
  private fun queue(): SoundQueue<MediaItem>? {
    val timeline = exo.currentTimeline
    if (timeline.isEmpty) return null
    val shuffled = exo.shuffleModeEnabled
    return SoundQueue.restore(
      entries = List(exo.mediaItemCount, exo::getMediaItemAt),
      order = timeline.playOrder(shuffled),
      currentIndex = exo.currentMediaItemIndex,
      repeatMode = repeatModeOf(exo.repeatMode),
      isShuffled = shuffled,
      // A track with no audio rides on a silent placeholder (see
      // `DeepSoundSessionCallback.onAddMediaItems`); it is never the next to play.
      canPlay = { it.mediaMetadata.isPlayable != false },
    )
  }

  /** Deals a shuffle that starts on [index] and gives it to the player. */
  private fun dealFrom(index: Int) {
    val count = exo.mediaItemCount
    if (count == 0) return
    val dealt = SoundQueue.start(
      entries = List(count) { it },
      startIndex = index,
      shuffled = true,
      repeatMode = RepeatMode.Off,
      canPlay = { true },
      random = random,
    )
    exo.setShuffleOrder(ShuffleOrder.DefaultShuffleOrder(dealt.order.toIntArray(), random.nextLong()))
  }

  // MARK: Commands

  /**
   * ExoPlayer's state, with Next and Previous available whenever there is a
   * queue to move through. A forwarding *simple* player, rather than a plain
   * `ForwardingPlayer`, for exactly this: its listeners hear the commands as
   * this state reports them, and the session redraws the notification's
   * buttons from what a change carries, not from asking the player.
   */
  override fun getState(): State {
    val state = super.getState()
    if (state.timeline.isEmpty) return state
    return state.buildUpon()
      .setAvailableCommands(state.availableCommands.buildUpon().addAll(*SKIPS).build())
      .build()
  }

  private companion object {
    val SKIPS = intArrayOf(
      Player.COMMAND_SEEK_TO_NEXT,
      Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM,
      Player.COMMAND_SEEK_TO_PREVIOUS,
      Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM,
    )
  }
}

// MARK: - Shared with SoundPlayer

/** This timeline's windows in play order — shuffled or not — from first to last. */
fun Timeline.playOrder(shuffled: Boolean): List<Int> {
  if (isEmpty) return emptyList()
  val order = ArrayList<Int>(windowCount)
  var index = getFirstWindowIndex(shuffled)
  while (index != C.INDEX_UNSET && order.size < windowCount) {
    order += index
    index = getNextWindowIndex(index, Player.REPEAT_MODE_OFF, shuffled)
  }
  return order
}

/** The [RepeatMode] a Media3 repeat mode stands for. */
fun repeatModeOf(@Player.RepeatMode mode: Int): RepeatMode = when (mode) {
  Player.REPEAT_MODE_ALL -> RepeatMode.All
  Player.REPEAT_MODE_ONE -> RepeatMode.One
  else -> RepeatMode.Off
}

/** This mode as Media3 spells it. */
@get:Player.RepeatMode
val RepeatMode.playerMode: Int
  get() = when (this) {
    RepeatMode.Off -> Player.REPEAT_MODE_OFF
    RepeatMode.All -> Player.REPEAT_MODE_ALL
    RepeatMode.One -> Player.REPEAT_MODE_ONE
  }
