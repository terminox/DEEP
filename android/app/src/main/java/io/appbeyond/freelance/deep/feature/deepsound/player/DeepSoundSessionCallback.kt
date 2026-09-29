@file:OptIn(UnstableApi::class)

package io.appbeyond.freelance.deep.feature.deepsound.player

import androidx.annotation.OptIn
import androidx.core.net.toUri
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaSession
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import io.appbeyond.freelance.deep.R

/**
 * Who may do what to DEEP Sound's session, and how queued items get their audio
 * back.
 *
 * No iOS counterpart: `AVPlayer` is owned by the app and `MPRemoteCommandCenter`
 * only ever offers transport. A `MediaSession` is a public, exported surface —
 * system UI, a watch, a car, or any app holding the right permission can
 * connect — so this is where that surface is narrowed to what iOS exposes.
 *
 * @param ownPackage this build's package, read at runtime so the `.dev` and
 *   `.staging` suffixes compare correctly.
 */
class DeepSoundSessionCallback(private val ownPackage: String) : MediaSession.Callback {

  /**
   * Foreign controllers get transport and nothing else.
   *
   * Everything outside this app — the system's media controls, Bluetooth, a
   * watch — can play, pause, skip and seek, which is exactly what the lock
   * screen can do on iOS. What they lose is the power to rewrite the queue or
   * change how it repeats: the queue is [SoundPlayer]'s, it mirrors it
   * index-for-index, and an outside edit would leave the app showing one track
   * while another plays. The media notification's own controller runs in this
   * package, so it keeps the full set.
   *
   * The narrowing starts from `AcceptedResultBuilder(session, controller)` —
   * the defaults Media3 grants that controller — never from
   * `super.onConnect`. Since Media3 1.11 the default `onConnect` returns a
   * placeholder that defers to `onConnectAsync` and carries no player
   * commands at all, so trimming *it* handed every foreign controller an
   * empty set: a headset's or the system's play/pause (which Media3 runs as
   * the calling controller) was refused without a sound.
   */
  override fun onConnect(
    session: MediaSession,
    controller: MediaSession.ControllerInfo,
  ): MediaSession.ConnectionResult {
    val defaults = MediaSession.ConnectionResult.AcceptedResultBuilder(session, controller)
    if (controller.packageName == ownPackage) return defaults.build()

    val transportOnly = defaults.build().availablePlayerCommands.buildUpon()
      .removeAll(
        Player.COMMAND_CHANGE_MEDIA_ITEMS,
        Player.COMMAND_SET_MEDIA_ITEM,
        Player.COMMAND_SET_REPEAT_MODE,
        Player.COMMAND_SET_SHUFFLE_MODE,
      )
      .build()
    return defaults.setAvailablePlayerCommands(transportOnly).build()
  }

  /**
   * Gives each arriving item its audio back.
   *
   * A `MediaController` sends items without their local configuration, so the
   * URI [toMediaItem] set is gone by the time they land here; the copy it left
   * in `requestMetadata.mediaUri` is restored instead. An item with neither — a
   * track with no audio yet — gets a second of bundled silence, so it still
   * occupies its slot and the queue's indices stay [SoundPlayer]'s indices. The
   * service pauses on it before a frame of the silence plays.
   */
  override fun onAddMediaItems(
    mediaSession: MediaSession,
    controller: MediaSession.ControllerInfo,
    mediaItems: MutableList<MediaItem>,
  ): ListenableFuture<MutableList<MediaItem>> =
    Futures.immediateFuture(mediaItems.map { it.withPlayableUri() }.toMutableList())

  private fun MediaItem.withPlayableUri(): MediaItem {
    val uri = localConfiguration?.uri ?: requestMetadata.mediaUri ?: silence
    return buildUpon().setUri(uri).build()
  }

  /** Resolved by the player's `DefaultDataSource`, as the hero video's loop is. */
  private val silence = "android.resource://$ownPackage/${R.raw.sound_unplayable}".toUri()
}
