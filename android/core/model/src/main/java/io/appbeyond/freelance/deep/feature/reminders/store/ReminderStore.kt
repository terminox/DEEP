package io.appbeyond.freelance.deep.feature.reminders.store

import io.appbeyond.freelance.deep.feature.reminders.model.DailyReminder
import io.appbeyond.freelance.deep.feature.reminders.model.ReminderSchedule
import io.appbeyond.freelance.deep.shared.persistence.BlobStoring
import io.appbeyond.freelance.deep.shared.persistence.StoreJson
import io.appbeyond.freelance.deep.shared.persistence.readOrNull
import io.appbeyond.freelance.deep.shared.persistence.writeQuietly
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * The daily reminder's settings, and the one place that keeps the system's
 * schedule agreeing with them.
 *
 * Ported from Deep/Deep/Features/Reminders/Store/ReminderStore.swift. Local
 * by design: nothing about the nudge reaches the server. It's a property of
 * this phone — the one that will actually buzz — so it does not follow the
 * account to another device. (Signing out and deleting the account still
 * switch it off, as on iOS: the nudge is about practice, and practice leaves
 * with the account — and, unlike iOS, the time goes back to the default too,
 * so the next member never inherits it: [reset].)
 *
 * The store deliberately doesn't know about practice. Whether today's goal is
 * already met arrives as an argument, so the rule stays testable and the
 * store stays a store.
 *
 * iOS decodes its `UserDefaults` blob synchronously in `init`; here [blob] is
 * read on first use, so every member restores first.
 *
 * @param zone read on every rebuild, so a member who changes timezone gets
 *   the new zone's 21:00 at the next reschedule (the system's
 *   TIMEZONE_CHANGED broadcast triggers one).
 */
class ReminderStore(
  private val scheduler: ReminderScheduling,
  private val blob: BlobStoring,
  private val clock: Clock,
  private val zone: () -> ZoneId,
) {

  data class State(
    val reminder: DailyReminder = DailyReminder.initial,
    val permission: ReminderPermission = ReminderPermission.Unasked,
  )

  private val _state = MutableStateFlow(State())

  val state: StateFlow<State> = _state.asStateFlow()

  /** The current settings. */
  val reminder: DailyReminder get() = _state.value.reminder

  private val restoreLock = Mutex()

  @Volatile
  private var restored = false

  /** Serialises every settings change together with its schedule rebuild, so
   * two quick taps can never leave the system queue on the older choice. */
  private val mutationLock = Mutex()

  /** Loads the persisted settings. Safe to call any number of times. */
  suspend fun restore() {
    if (restored) return
    restoreLock.withLock {
      if (restored) return
      val stored = blob.readOrNull()?.let { json ->
        runCatching { StoreJson.decodeFromString(DailyReminder.serializer(), json) }.getOrNull()
      }
      _state.value = _state.value.copy(reminder = stored ?: DailyReminder.initial)
      restored = true
    }
  }

  /** Picks up the system's answer without prompting. Safe to call on every
   * foreground: permission can change in system settings while the app sleeps. */
  suspend fun refreshPermission() {
    restore()
    val permission = scheduler.permission()
    _state.value = _state.value.copy(permission = permission)
  }

  /**
   * Turns the reminder on, prompting for permission the first time.
   *
   * Returns the settled permission so the screen can explain a refusal rather
   * than leaving a toggle that silently springs back.
   *
   * @param prompt shows the system's notification permission dialog.
   */
  suspend fun enable(goalMetToday: Boolean, prompt: suspend () -> Boolean): ReminderPermission {
    restore()
    return mutate {
      val permission = scheduler.requestPermission(prompt)
      _state.value = _state.value.copy(permission = permission)
      if (permission != ReminderPermission.Granted) {
        // Never leave the toggle on over a queue that can't exist.
        write(reminder.copy(isEnabled = false))
      } else {
        write(reminder.copy(isEnabled = true), goalMetToday)
      }
      permission
    }
  }

  suspend fun disable() {
    restore()
    mutate { write(reminder.copy(isEnabled = false)) }
  }

  /**
   * Records that today's nudge has just been posted, so no rebuild today —
   * a later clock face, a foreground, the receiver's own re-arm — queues a
   * second one. The queue itself is left to the caller's [reschedule].
   */
  suspend fun markPosted(day: LocalDate) {
    restore()
    mutate {
      val updated = reminder.copy(lastPostedDay = day.toString())
      _state.value = _state.value.copy(reminder = updated)
      blob.writeQuietly(StoreJson.encodeToString(DailyReminder.serializer(), updated))
    }
  }

  /**
   * Back to [DailyReminder.initial] — off, at 21:00 — with the queue cleared.
   * Every account exit calls this rather than [disable], so the next member
   * on this phone starts clean instead of arming the last one's clock face
   * (QA round 1, B8).
   */
  suspend fun reset() {
    restore()
    mutate { write(DailyReminder.initial) }
  }

  /** Adopts a new clock face; the day is meaningless for a daily nudge. */
  suspend fun setTime(hour: Int, minute: Int, goalMetToday: Boolean) {
    restore()
    mutate {
      val updated = reminder.withTime(hour, minute)
      if (updated != reminder) write(updated, goalMetToday)
    }
  }

  /**
   * Rebuilds the schedule from the current settings.
   *
   * Called on every foreground (the window rolls forward, and today's goal
   * may since have been met), as the app leaves the foreground, after a
   * reminder fires, and on boot or a clock/zone change, because the system
   * forgets alarms across a reboot.
   */
  suspend fun reschedule(goalMetToday: Boolean) {
    restore()
    mutate {
      if (!reminder.isEnabled) {
        scheduler.clearQueue()
        return@mutate
      }
      val permission = scheduler.permission()
      _state.value = _state.value.copy(permission = permission)
      if (permission != ReminderPermission.Granted) {
        // Permission revoked in system settings while we were away: stop
        // claiming the reminder is on.
        write(reminder.copy(isEnabled = false))
        return@mutate
      }
      pushQueue(goalMetToday)
    }
  }

  // MARK: - Internals

  /** Runs [block] under [mutationLock], to completion even if the caller is
   * cancelled — the persisted choice and the system queue must agree. */
  private suspend fun <T> mutate(block: suspend () -> T): T =
    withContext(NonCancellable) { mutationLock.withLock { block() } }

  private suspend fun write(updated: DailyReminder, goalMetToday: Boolean = false) {
    _state.value = _state.value.copy(reminder = updated)
    blob.writeQuietly(StoreJson.encodeToString(DailyReminder.serializer(), updated))
    if (updated.isEnabled) {
      pushQueue(goalMetToday)
    } else {
      scheduler.clearQueue()
    }
  }

  private suspend fun pushQueue(goalMetToday: Boolean) {
    val now = ZonedDateTime.ofInstant(clock.instant(), zone())
    // Today is done either way: practised, or already nudged once.
    val skipToday = goalMetToday || reminder.postedOn(now.toLocalDate())
    scheduler.replaceQueue(
      ReminderSchedule.occurrences(after = now, reminder = reminder, goalMetToday = skipToday)
    )
  }
}
