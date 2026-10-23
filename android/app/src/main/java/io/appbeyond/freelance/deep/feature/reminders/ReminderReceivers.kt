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
 * out) posts nothing. Reads today's practice too: the reschedule that would
 * have quieted tonight runs as DEEP leaves the foreground, and a process that
 * died before it left this alarm armed over a practised day. Runs under
 * `goAsync`, because the stores read DataStore.
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
          val today = LocalDate.now(ZoneId.systemDefault())
          val day = intent.getStringExtra(AlarmReminderScheduler.EXTRA_DAY)
            ?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
            ?: today
          val journal = dependencies.practiceJournal
          journal.restore()
          // Today already counts as practised: tonight rests, as the
          // reschedule would have had it.
          if (!(day == today && journal.reminderRestsToday())) {
            AlarmReminderScheduler.post(
              localized = dependencies.languageStore.localized(context.applicationContext),
              day = day,
            )
            // Once a day: a later clock face set this evening arms tomorrow.
            store.markPosted(day)
          }
        }
        // Against today's practice, so a rested or nudged day arms the next.
        dependencies.rescheduleReminder()
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
