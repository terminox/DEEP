package io.appbeyond.freelance.deep.feature.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.appbeyond.freelance.deep.DeepApplication
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId

/**
 * The daily reminder's alarm: post today's nudge, then arm tomorrow's.
 *
 * Reads the settings first, so an alarm that outlived a switch-off (or a log
 * out) posts nothing. Runs under `goAsync`, because the store reads DataStore.
 */
class ReminderAlarmReceiver : BroadcastReceiver() {

  override fun onReceive(context: Context, intent: Intent) {
    val dependencies = (context.applicationContext as? DeepApplication)?.dependencies ?: return
    val pending = goAsync()
    receiverScope.launch {
      try {
        val store = dependencies.reminderStore
        store.restore()
        if (store.reminder.isEnabled) {
          // The day the alarm was armed for, so one delivered late past
          // midnight is booked to the evening it belongs to.
          val day = intent.getStringExtra(AlarmReminderScheduler.EXTRA_DAY)
            ?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
            ?: LocalDate.now(ZoneId.systemDefault())
          AlarmReminderScheduler.post(
            localized = dependencies.languageStore.localized(context.applicationContext),
            day = day,
          )
          // Once a day: a later clock face set this evening arms tomorrow.
          store.markPosted(day)
        }
        // Strictly after now, so this arms tomorrow's occurrence.
        store.reschedule(practisedToday = false)
      } catch (unexpected: Exception) {
        Log.w(TAG, "Reminder alarm failed", unexpected)
      } finally {
        pending.finish()
      }
    }
  }
}

/**
 * Re-arms the reminder after a reboot, an app update, or a change to the
 * device clock or timezone — the system drops alarms across a reboot, and a
 * new zone moves the wall-clock time the member chose.
 */
class ReminderRescheduleReceiver : BroadcastReceiver() {

  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action !in HANDLED) return
    val dependencies = (context.applicationContext as? DeepApplication)?.dependencies ?: return
    val pending = goAsync()
    receiverScope.launch {
      try {
        dependencies.rescheduleReminder()
      } catch (unexpected: Exception) {
        Log.w(TAG, "Reminder reschedule failed", unexpected)
      } finally {
        pending.finish()
      }
    }
  }

  private companion object {
    val HANDLED = setOf(
      Intent.ACTION_BOOT_COMPLETED,
      Intent.ACTION_TIME_CHANGED,
      Intent.ACTION_TIMEZONE_CHANGED,
      Intent.ACTION_MY_PACKAGE_REPLACED,
    )
  }
}

private const val TAG = "Reminders"

/** Receivers outlive no screen; their work is bounded by `goAsync`. */
private val receiverScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
