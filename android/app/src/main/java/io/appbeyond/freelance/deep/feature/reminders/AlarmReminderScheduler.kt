package io.appbeyond.freelance.deep.feature.reminders

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.appbeyond.freelance.deep.MainActivity
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.reminders.model.ReminderCopy
import io.appbeyond.freelance.deep.feature.reminders.model.ReminderSchedule
import io.appbeyond.freelance.deep.feature.reminders.store.ReminderPermission
import io.appbeyond.freelance.deep.feature.reminders.store.ReminderScheduling
import java.time.LocalDate
import java.time.ZonedDateTime

/**
 * Backs the daily reminder with [AlarmManager] and a notification channel —
 * the Android twin of `ReminderScheduler` (UNUserNotificationCenter) on iOS.
 *
 * **One alarm, re-armed.** iOS queues eight weeks of dated requests because it
 * cannot run code when one fires. Android can: only the first occurrence of
 * the queue is armed, and [ReminderAlarmReceiver] posts it and asks the store
 * to rebuild, which arms the next. `BOOT_COMPLETED`, `TIME_SET` and
 * `TIMEZONE_CHANGED` rebuild it too ([ReminderRescheduleReceiver]), because
 * the system forgets alarms across a reboot.
 *
 * **Inexact, in a ten-minute window.** `setWindow` from the chosen minute.
 * An exact alarm would need `SCHEDULE_EXACT_ALARM`, which is denied by default
 * from Android 14 and can only be granted from a system settings page — a
 * second permission journey for a nudge whose whole register is "whenever
 * you're ready". A plain `set` is worse: the system may defer it by up to
 * three quarters of the time until it is due, hours for an evening alarm set
 * in the morning. Ten minutes is the shortest window the system honours. In
 * deep Doze the nudge waits for the next maintenance window, which is a
 * phone nobody is holding.
 *
 * **Quiet, as on iOS.** iOS posts `.passive` (no sound, no lit screen) and
 * never badges — a count on the icon is a debt display. The channel is
 * `IMPORTANCE_LOW` with no badge for the same reasons.
 *
 * **Permission.** `POST_NOTIFICATIONS` exists from API 33; below that,
 * notifications are on unless switched off in Settings, which no prompt can
 * undo. Android can't tell "never asked" from "refused for good" without a
 * prompt, so a refusal is remembered for the process and otherwise
 * "not granted" reads as [ReminderPermission.Unasked] — a prompt the system
 * won't show again returns at once as refused.
 */
class AlarmReminderScheduler(private val context: Context) : ReminderScheduling {

  @Volatile
  private var refusedThisProcess = false

  override suspend fun permission(): ReminderPermission = when {
    canPost() -> ReminderPermission.Granted
    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !refusedThisProcess -> ReminderPermission.Unasked
    else -> ReminderPermission.Denied
  }

  override suspend fun requestPermission(prompt: suspend () -> Boolean): ReminderPermission {
    if (canPost()) return ReminderPermission.Granted
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return ReminderPermission.Denied
    val granted = prompt() && canPost()
    if (!granted) refusedThisProcess = true
    return if (granted) ReminderPermission.Granted else ReminderPermission.Denied
  }

  override suspend fun replaceQueue(occurrences: List<ZonedDateTime>) {
    val next = occurrences.firstOrNull()
    if (next == null) {
      clearQueue()
      return
    }
    ensureChannel(context)
    val alarms = context.getSystemService(AlarmManager::class.java) ?: return
    alarms.setWindow(
      AlarmManager.RTC_WAKEUP,
      next.toInstant().toEpochMilli(),
      WINDOW_MILLIS,
      alarmIntent(context, day = next.toLocalDate()),
    )
  }

  override suspend fun clearQueue() {
    context.getSystemService(AlarmManager::class.java)?.cancel(alarmIntent(context))
  }

  private fun canPost(): Boolean {
    if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
      if (granted != PackageManager.PERMISSION_GRANTED) return false
    }
    return true
  }

  companion object {
    const val CHANNEL_ID = "deep.reminder"
    private const val NOTIFICATION_ID = 21
    private const val REQUEST_ALARM = 21
    private const val REQUEST_OPEN = 22
    private val WINDOW_MILLIS = ReminderSchedule.deliveryWindow.toMillis()

    /** The armed occurrence's own local day, carried to [ReminderAlarmReceiver]
     * so a nudge delivered after midnight is booked to the day it belongs to. */
    const val EXTRA_DAY = "io.appbeyond.freelance.deep.reminder.DAY"

    private fun alarmIntent(context: Context, day: LocalDate? = null): PendingIntent = PendingIntent.getBroadcast(
      context,
      REQUEST_ALARM,
      Intent(context, ReminderAlarmReceiver::class.java).apply {
        if (day != null) putExtra(EXTRA_DAY, day.toString())
      },
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /** The channel members see in system settings, named in the reading language. */
    fun ensureChannel(context: Context) {
      val manager = context.getSystemService(NotificationManager::class.java) ?: return
      val channel = NotificationChannel(
        CHANNEL_ID,
        context.getString(R.string.reminder_channel_name),
        NotificationManager.IMPORTANCE_LOW,
      ).apply {
        description = context.getString(R.string.reminder_channel_description)
        setShowBadge(false)
      }
      manager.createNotificationChannel(channel)
    }

    /**
     * Posts today's nudge in [localized]'s language — resolved now, as it
     * fires, so a language picked since it was armed is the one it speaks.
     */
    fun post(localized: Context, day: LocalDate) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
        ContextCompat.checkSelfPermission(localized, Manifest.permission.POST_NOTIFICATIONS) !=
        PackageManager.PERMISSION_GRANTED
      ) {
        return
      }
      ensureChannel(localized)
      val titles = localized.resources.getStringArray(R.array.reminder_copy_titles)
      val bodies = localized.resources.getStringArray(R.array.reminder_copy_bodies)
      val index = ReminderCopy.indexFor(day, minOf(titles.size, bodies.size))
      val open = PendingIntent.getActivity(
        localized,
        REQUEST_OPEN,
        Intent(localized, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
      val notification = NotificationCompat.Builder(localized, CHANNEL_ID)
        .setSmallIcon(R.drawable.ic_stat_deep)
        .setContentTitle(titles[index])
        .setContentText(bodies[index])
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setCategory(NotificationCompat.CATEGORY_REMINDER)
        .setAutoCancel(true)
        .setContentIntent(open)
        .build()
      NotificationManagerCompat.from(localized).notify(NOTIFICATION_ID, notification)
    }
  }
}
