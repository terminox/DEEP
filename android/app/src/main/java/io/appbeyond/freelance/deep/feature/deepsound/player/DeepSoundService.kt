@file:OptIn(UnstableApi::class)

package io.appbeyond.freelance.deep.feature.deepsound.player

import android.app.PendingIntent
import android.content.Intent
import android.util.Log
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import io.appbeyond.freelance.deep.DeepApplication
import io.appbeyond.freelance.deep.MainActivity
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.model.Advance
import io.appbeyond.freelance.deep.feature.deepsound.model.ListenRules
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundPlayback
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueue
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore

/**
 * Where DEEP Sound's audio actually plays: one `ExoPlayer` behind one
 * `MediaSession`, in a service so it keeps playing with the screen off and the
 * app in the background.
 *
 * The Android half of `StreamingSoundPlayer.swift`. iOS gets background audio by
 * declaring `UIBackgroundModes` and claiming the `.playback` session category;
 * Android needs a foreground service with a media notification, and
 * `MediaSessionService` supplies both — it promotes itself to the foreground
 * while playing and drops back when paused, so a paused queue never pins a
 * notification the member cannot swipe away.
 *
 * The app never touches this player directly. [SoundPlayer] drives it through a
 * `MediaController`, exactly as the notification, the lock screen and a
 * Bluetooth headset do, so there is one player and every surface sees the same
 * state.
 *
 * Runs in the app's own process, so it reads its dependencies from the one
 * composition root rather than building a second HTTP stack of its own.
 */
class DeepSoundService : MediaSessionService() {

  private var session: MediaSession? = null

  override fun onCreate() {
    super.onCreate()
    val dependencies = (application as DeepApplication).dependencies

    val player = ExoPlayer.Builder(this)
      // Music, with focus handled by the player: a call or a navigation prompt
      // pauses or ducks us, and we duck or pause whatever was playing before.
      // iOS gets the same from the `.playback` category.
      .setAudioAttributes(
        AudioAttributes.Builder()
          .setUsage(C.USAGE_MEDIA)
          .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
          .build(),
        /* handleAudioFocus = */ true,
      )
      // Headphones pulled out mid-track pause rather than start playing through
      // the speaker — iOS's route-change behaviour, which Android leaves opt-in.
      .setHandleAudioBecomingNoisy(true)
      // Streams keep buffering with the screen off: CPU and Wi-Fi both stay up
      // while playing, released the moment playback stops.
      .setWakeMode(C.WAKE_MODE_NETWORK)
      // iOS's `previous()`: past three seconds in, it restarts the track. The
      // notification's and the headset's previous buttons go through the
      // player, not through SoundPlayer, so the rule has to live here too.
      .setMaxSeekToPreviousPositionMs((SoundQueue.RESTART_THRESHOLD_SECONDS * 1_000).toLong())
      // Audio streams on the media client: the shared pool and dispatcher, but
      // none of the API's headers, bearer token or call timeout (see
      // `DeepHttp.mediaClient`). DefaultDataSource wraps it so the silent
      // placeholder in res/raw still resolves.
      .setMediaSourceFactory(
        DefaultMediaSourceFactory(
          DefaultDataSource.Factory(this, OkHttpDataSource.Factory(dependencies.http.mediaClient))
        )
      )
      .build()
      .apply {
        // The queue repeats forever, as every iOS player does.
        repeatMode = Player.REPEAT_MODE_ALL
        volume = SoundPlayback.DEFAULT_VOLUME.toFloat()
      }

    player.addListener(PlaybackWatcher(dependencies.trackListens, dependencies.accountStore))

    setMediaNotificationProvider(
      DefaultMediaNotificationProvider.Builder(this).build().apply {
        setSmallIcon(R.drawable.ic_stat_deep)
      }
    )

    // Android 12+ refuses a foreground start from the background in a handful of
    // edge cases Media3 cannot rule out (a Bluetooth play while the app is
    // cached, say). Media3 already keeps playing without the notification; all
    // that is left to do is say so in the log.
    setListener(object : MediaSessionService.Listener {
      override fun onForegroundServiceStartNotAllowedException() {
        Log.w(TAG, "Foreground start refused; playing on without a notification.")
      }
    })

    session = MediaSession.Builder(this, player)
      .setId(SESSION_ID)
      .setCallback(DeepSoundSessionCallback(packageName))
      // Tapping the notification returns to the app as it was — MainActivity is
      // singleTop, so this surfaces the running task rather than stacking a
      // second copy of it.
      .setSessionActivity(
        PendingIntent.getActivity(
          this,
          0,
          Intent(this, MainActivity::class.java),
          PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
      )
      .build()
  }

  override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

  override fun onDestroy() {
    session?.run {
      player.release()
      release()
    }
    session = null
    super.onDestroy()
  }

  /**
   * Two jobs that belong to the player itself, not to any one controller of it:
   * reporting a natural finish, and refusing to play a track with no audio.
   */
  private inner class PlaybackWatcher(
    private val listens: TrackListenReporting,
    private val accounts: AccountStore,
  ) : Player.Listener {

    /**
     * An auto-transition is the one discontinuity that means "played to the
     * end" — iOS's `AVPlayerItemDidPlayToEndTime`. With the queue repeating it
     * fires for the last track too, and for a one-track queue looping on itself.
     * Seeks and skips arrive with other reasons and never report.
     */
    override fun onPositionDiscontinuity(
      oldPosition: Player.PositionInfo,
      newPosition: Player.PositionInfo,
      reason: Int,
    ) {
      if (reason != Player.DISCONTINUITY_REASON_AUTO_TRANSITION) return
      val finished = oldPosition.mediaItem ?: return
      val report = ListenRules.shouldReportListen(
        advance = Advance.Natural,
        playable = finished.mediaMetadata.isPlayable == true,
        signedIn = accounts.account.value != null,
      )
      if (report) listens.trackFinished(finished.mediaId)
    }

    override fun onEvents(player: Player, events: Player.Events) {
      // A track with no audio carries a second of silence so the queue keeps
      // its shape; it must never actually play. Checked on every event, not
      // just transitions, because a `play()` on it arrives as a change to
      // playWhenReady with no transition at all.
      val current = player.currentMediaItem
      if (player.playWhenReady && current?.mediaMetadata?.isPlayable == false) {
        player.pause()
      }

      // Cleared — the member logged out, or SoundPlayer let go. Nothing is left
      // to play, so there is no reason to stay alive once the last controller
      // unbinds.
      if (player.playbackState == Player.STATE_IDLE && player.mediaItemCount == 0) {
        stopSelf()
      }
    }
  }

  private companion object {
    const val TAG = "DeepSoundService"
    const val SESSION_ID = "deep-sound"
  }
}
