package io.appbeyond.freelance.deep.feature.globalpause.audio

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import io.appbeyond.freelance.deep.DeepApplication
import io.appbeyond.freelance.deep.MainActivity
import io.appbeyond.freelance.deep.R

/**
 * Keeps the process in the foreground while the meditation plays.
 *
 * iOS's meditation keeps playing with the phone locked because the app holds
 * the `.playback` audio category and background audio, and its presence
 * heartbeats keep beating with it. Android needs a foreground service for the
 * same promise: without one, a locked phone soon has its process cached and
 * frozen, the meditation falls silent and the beats that earn the night's
 * hearts stop. The player lives in [GlobalPauseAudioPlayer]; this service only
 * holds the process up and shows the quiet ongoing notification the platform
 * requires — the Android twin of iOS's Now Playing entry ("Global Pause · The
 * world, breathing together").
 *
 * Deliberately not a `MediaSessionService`: a media session would put play,
 * pause and seek on the lock screen and the headset, and this meditation has
 * none of those. Started only while the app is in the foreground (the session
 * screen), which is when Android allows it.
 */
class GlobalPauseService : Service() {

  /**
   * Below API 33 the per-app locale doesn't reach a service, so its channel
   * and notification read in the chosen language only through `LanguageStore`
   * — as `MainActivity` does; from 33 the system has already applied it.
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

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    ensureChannel(this)
    val open = PendingIntent.getActivity(
      this,
      REQUEST_OPEN,
      Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val notification = NotificationCompat.Builder(this, CHANNEL_ID)
      .setSmallIcon(R.drawable.ic_stat_deep)
      .setContentTitle(getString(R.string.pause_notification_title))
      .setContentText(getString(R.string.pause_notification_body))
      .setOngoing(true)
      .setOnlyAlertOnce(true)
      .setSilent(true)
      .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .setContentIntent(open)
      .build()
    ServiceCompat.startForeground(
      this,
      NOTIFICATION_ID,
      notification,
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK else 0,
    )
    // A process killed mid-meditation must not come back to a session that is
    // no longer running.
    return START_NOT_STICKY
  }

  companion object {
    private const val CHANNEL_ID = "deep.global_pause"
    private const val NOTIFICATION_ID = 31
    private const val REQUEST_OPEN = 31

    fun start(context: Context) {
      try {
        ContextCompat.startForegroundService(context, Intent(context, GlobalPauseService::class.java))
      } catch (refused: IllegalStateException) {
        // Started from the background after all (a resume racing a stop). The
        // meditation still plays while the process lives; it just isn't held up.
        android.util.Log.w("GlobalPauseService", "Foreground start refused", refused)
      }
    }

    fun stop(context: Context) {
      context.stopService(Intent(context, GlobalPauseService::class.java))
    }

    private fun ensureChannel(context: Context) {
      val manager = context.getSystemService(NotificationManager::class.java) ?: return
      val channel = NotificationChannel(
        CHANNEL_ID,
        context.getString(R.string.pause_channel_name),
        NotificationManager.IMPORTANCE_LOW,
      ).apply {
        setShowBadge(false)
        setSound(null, null)
      }
      manager.createNotificationChannel(channel)
    }
  }
}
