@file:OptIn(UnstableApi::class)

package io.appbeyond.freelance.deep.feature.deepsound.player

import android.content.Intent
import android.view.KeyEvent
import androidx.annotation.OptIn
import androidx.core.content.IntentCompat
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
 * @param isHeld whether a practice holds DEEP Sound silent
 *   (`SoundPlaying.holdPlayback`) — see [connectionFor].
 * @param onNothingToResume a play arrived with no queue loaded — see
 *   [onPlaybackResumption]. The service stops itself cleanly.
 */
class DeepSoundSessionCallback(
  private val ownPackage: String,
  private val isHeld: () -> Boolean = { false },
  private val onNothingToResume: () -> Unit = {},
) : MediaSession.Callback {

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
  ): MediaSession.ConnectionResult = connectionFor(session, controller)

  /**
   * What [controller] may do right now.
   *
   * While DEEP Sound is held for a practice, every controller but the app's
   * own [SoundPlayer] — the media notification's (which also stands for the
   * platform session the system UI and a headset talk to), and every foreign
   * one — loses `COMMAND_PLAY_PAUSE`, so the play button leaves the
   * notification and the lock screen rather than sitting there refusing. On
   * Android 8–12 that matters beyond looks: a paused notification's play is a
   * foreground-service start, and a play that is then dropped would leave the
   * service owing Android a `startForeground` it never gets. [SoundPlayer]
   * keeps its full set (it refuses itself while held, and still needs to
   * pause).
   */
  fun connectionFor(
    session: MediaSession,
    controller: MediaSession.ControllerInfo,
  ): MediaSession.ConnectionResult {
    val defaults = MediaSession.ConnectionResult.AcceptedResultBuilder(session, controller)
    val isNotification = session.isMediaNotificationController(controller)
    val isForeign = controller.packageName != ownPackage
    if (!isForeign && !isNotification) return defaults.build()

    val commands = defaults.build().availablePlayerCommands.buildUpon()
    if (isForeign) {
      commands.removeAll(
        Player.COMMAND_CHANGE_MEDIA_ITEMS,
        Player.COMMAND_SET_MEDIA_ITEM,
        Player.COMMAND_SET_REPEAT_MODE,
        Player.COMMAND_SET_SHUFFLE_MODE,
      )
    }
    if (isHeld()) commands.remove(Player.COMMAND_PLAY_PAUSE)
    return defaults.setAvailablePlayerCommands(commands.build()).build()
  }

  /**
   * Re-grants every connected controller what [connectionFor] says now — the
   * hold was taken or released. Media3 redraws the notification (and the
   * platform session's actions) from the notification controller's new set.
   */
  fun refreshCommands(session: MediaSession) {
    session.connectedControllers.forEach { controller ->
      if (controller.packageName == ownPackage && !session.isMediaNotificationController(controller)) {
        return@forEach
      }
      val granted = connectionFor(session, controller)
      session.setAvailableCommands(controller, granted.availableSessionCommands, granted.availablePlayerCommands)
    }
  }

  /**
   * A media button that would start playback while held — a tap on a play
   * button drawn before the hold took it away, or a headset — is swallowed
   * here, before Media3 turns it into a play. Had it arrived as a
   * foreground-service start, `DeepSoundService.onStartCommand` has already
   * paid the `startForeground` it owed, under the paused notification.
   */
  override fun onMediaButtonEvent(
    session: MediaSession,
    controllerInfo: MediaSession.ControllerInfo,
    intent: Intent,
  ): Boolean {
    if (!isHeld()) return false
    val key = IntentCompat.getParcelableExtra(intent, Intent.EXTRA_KEY_EVENT, KeyEvent::class.java) ?: return false
    return key.keyCode in HELD_KEYS
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

  /**
   * A play with nothing loaded: Media3 asks what to resume.
   *
   * The queue lives in [SoundPlayer] for the process's lifetime and is never
   * persisted, so a play that arrives here — in practice, a headset or the
   * play button of a notification that outlived its process — has nothing to
   * resume. This fails quietly (Media3's default `UnsupportedOperationException`
   * logs as if the app forgot something) and has the service stop. The
   * foreground start such a play owes is paid before it gets here, in
   * `DeepSoundService.onStartCommand`.
   */
  override fun onPlaybackResumption(
    mediaSession: MediaSession,
    controller: MediaSession.ControllerInfo,
    isForPlayback: Boolean,
  ): ListenableFuture<MediaSession.MediaItemsWithStartPosition> {
    if (isForPlayback) onNothingToResume()
    return Futures.immediateFailedFuture(IllegalStateException("No DEEP Sound queue to resume."))
  }

  private fun MediaItem.withPlayableUri(): MediaItem {
    val uri = localConfiguration?.uri ?: requestMetadata.mediaUri ?: silence
    return buildUpon().setUri(uri).build()
  }

  private companion object {
    /** The keys that would start a paused player. */
    val HELD_KEYS = setOf(
      KeyEvent.KEYCODE_MEDIA_PLAY,
      KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
      KeyEvent.KEYCODE_HEADSETHOOK,
    )
  }

  /** Resolved by the player's `DefaultDataSource`, as the hero video's loop is. */
  private val silence = "android.resource://$ownPackage/${R.raw.sound_unplayable}".toUri()
}
