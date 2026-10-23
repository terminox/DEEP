@file:OptIn(UnstableApi::class)

package io.appbeyond.freelance.deep.feature.deepsound.player

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.OptIn
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.ForwardingPlayer
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
import kotlinx.coroutines.Job
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch

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

  /**
   * Below Android 13 the per-app language is not the process's, so the media
   * notification — its channel name and Media3's button descriptions, which
   * ship in Thai — would read in the system language. `GlobalPauseService`'s
   * wrapping, for the same reason.
   */
  override fun attachBaseContext(newBase: Context) {
    val dependencies = (newBase.applicationContext as? DeepApplication)?.dependencies
    val localized = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU && dependencies != null) {
      dependencies.languageStore.localized(newBase)
    } else {
      newBase
    }
    super.attachBaseContext(localized)
  }

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

    // Every controller reaches the player through this one — the app's own
    // SoundPlayer and the notification, lock screen and headset alike — so a
    // practice's hold (SoundPlaying.holdPlayback) is refused in one place.
    val guarded = HoldingPlayer(player, isHeld = { dependencies.soundPlayer.isPlaybackHeld })

    val callback = DeepSoundSessionCallback(
      ownPackage = packageName,
      isHeld = { dependencies.soundPlayer.isPlaybackHeld },
      // Posted, so Media3 finishes handling the play it was given before
      // the session it belongs to is torn down.
      onNothingToResume = { mainHandler.post(::stopWithNothingToResume) },
    )

    val built = MediaSession.Builder(this, guarded)
      .setId(SESSION_ID)
      .setCallback(callback)
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
    session = built

    // Taking or releasing the hold re-grants every controller its commands,
    // so the notification's play button leaves with the hold and comes back
    // after it.
    holdWatch = serviceScope.launch {
      dependencies.soundPlayer.playbackHeld
        .drop(1)
        .collect { callback.refreshCommands(built) }
    }
  }

  private val serviceScope = MainScope()
  private var holdWatch: Job? = null

  override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

  private val mainHandler = Handler(Looper.getMainLooper())

  /**
   * Pays a foreground start this service may owe before Media3 sees the
   * intent — synchronously, inside the start itself.
   *
   * A media button reaches this service as a `startForegroundService`: a
   * paused notification's play button, or — after the process was killed —
   * the media-button PendingIntent the platform session left registered,
   * which a headset or `media dispatch play` fires. Android then demands a
   * `startForeground` within seconds, and crashes the app if the service is
   * brought down first. Two such starts can never go foreground on their own:
   *
   * - **Nothing to resume.** A fresh process has no queue (it lives in
   *   [SoundPlayer], for a process's lifetime), so playback resumption fails
   *   and nothing plays. Paid under a silent placeholder with the media
   *   notification's id and taken straight down, which also clears a stale
   *   notification; [stopWithNothingToResume] then stops the service.
   * - **Held for a practice.** The play is refused (see
   *   [DeepSoundSessionCallback.onMediaButtonEvent]). Paid under the paused
   *   notification already showing, which stays exactly as it was.
   *
   * Paying here rather than once Media3 has failed the resumption matters:
   * Media3 handles the key on a later turn of the main looper, and anything
   * that brings the service down before then — the crash QA hit on API 26 —
   * would beat a payment made there.
   */
  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (intent?.action == Intent.ACTION_MEDIA_BUTTON && !isPlaybackOngoing) {
      val player = session?.player
      when {
        player == null || player.mediaItemCount == 0 -> payForegroundDebt(keepNotification = false)
        (application as DeepApplication).dependencies.soundPlayer.isPlaybackHeld ->
          payForegroundDebt(keepNotification = true)
      }
    }
    val result = super.onStartCommand(intent, flags, startId)
    // The system's sticky restart after the process was killed: no intent,
    // and no queue to serve (it died with the process). Nothing is owed on a
    // restart, so the empty service simply goes; a later media key starts it
    // afresh through the branch above.
    if (intent == null && (session?.player?.mediaItemCount ?: 0) == 0) stopSelf()
    return result
  }

  /**
   * The end of a play with no queue to resume — see [onStartCommand], which
   * has already settled the foreground start. Nothing plays: iOS's lock screen
   * has nothing to resume after its app is gone, either. Skipped if the app
   * has since loaded a queue.
   */
  private fun stopWithNothingToResume() {
    val player = session?.player ?: return
    if (player.mediaItemCount > 0) return
    stopSelf()
  }

  /**
   * Enters the foreground and leaves it again at once — what a service started
   * by `startForegroundService` must do before it may stay quiet or stop. With
   * [keepNotification] it does so under the media notification already showing
   * and leaves that notification up; otherwise under a silent placeholder with
   * the media notification's id, taking both down. Where the system refuses the
   * start (Android 12+'s background rule) nothing was owed.
   */
  // The media-playback service type is a compile-time constant ServiceCompat
  // ignores below API 29, as Media3's own shutdown does.
  @SuppressLint("InlinedApi")
  private fun payForegroundDebt(keepNotification: Boolean) {
    val id = DefaultMediaNotificationProvider.DEFAULT_NOTIFICATION_ID
    try {
      val showing = if (keepNotification) {
        getSystemService(NotificationManager::class.java)?.activeNotifications
          ?.firstOrNull { it.id == id }
          ?.notification
      } else {
        null
      }
      ServiceCompat.startForeground(
        this,
        id,
        showing ?: placeholderNotification(),
        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
      )
      ServiceCompat.stopForeground(
        this,
        if (showing != null) ServiceCompat.STOP_FOREGROUND_DETACH else ServiceCompat.STOP_FOREGROUND_REMOVE,
      )
    } catch (refused: IllegalStateException) {
      Log.w(TAG, "Could not settle a foreground start.", refused)
    }
  }

  /** Silent and secret: it exists only for the instant [payForegroundDebt] needs one. */
  private fun placeholderNotification(): Notification {
    NotificationManagerCompat.from(this).createNotificationChannel(
      NotificationChannelCompat.Builder(
        DefaultMediaNotificationProvider.DEFAULT_CHANNEL_ID,
        NotificationManagerCompat.IMPORTANCE_LOW,
      ).setName(getString(androidx.media3.session.R.string.default_notification_channel_name)).build()
    )
    return NotificationCompat.Builder(this, DefaultMediaNotificationProvider.DEFAULT_CHANNEL_ID)
      .setSmallIcon(R.drawable.ic_stat_deep)
      .setVisibility(NotificationCompat.VISIBILITY_SECRET)
      .setSilent(true)
      .build()
  }

  override fun onDestroy() {
    holdWatch?.cancel()
    serviceScope.cancel()
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

    /** Whether this player has held a queue since it was created or last cleared. */
    private var hadQueue = false

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
      // unbinds. Only once a queue has been here: a service just started for a
      // media key sits idle and empty from birth, and stopping it then — before
      // its start is even handled — is what Android punishes as a foreground
      // start never made.
      if (player.mediaItemCount > 0) hadQueue = true
      if (hadQueue && player.playbackState == Player.STATE_IDLE && player.mediaItemCount == 0) {
        hadQueue = false
        stopSelf()
      }
    }
  }

  /**
   * The service's player as every controller sees it: the real one, except
   * that while DEEP Sound is held for a practice ([isHeld]) a request to play
   * is dropped. Pausing, seeking and skipping still pass — only starting is
   * refused, which is all a hold is for.
   */
  private class HoldingPlayer(
    player: Player,
    private val isHeld: () -> Boolean,
  ) : ForwardingPlayer(player) {

    override fun play() {
      if (!isHeld()) super.play()
    }

    override fun setPlayWhenReady(playWhenReady: Boolean) {
      if (playWhenReady && isHeld()) return
      super.setPlayWhenReady(playWhenReady)
    }
  }

  private companion object {
    const val TAG = "DeepSoundService"
    const val SESSION_ID = "deep-sound"
  }
}
