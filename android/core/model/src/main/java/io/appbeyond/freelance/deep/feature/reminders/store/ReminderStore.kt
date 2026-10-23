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
   * The prompt is answered before the lock is taken, and stays cancellable: it
   * waits on a person, and on an activity that may be recreated (or never
   * answer) while the dialog is up. Holding the lock across it stalled every
   * reschedule, toggle and alarm behind an answer that might never come.
   *
   * @param prompt shows the system's notification permission dialog.
   */
  suspend fun enable(practisedToday: Boolean, prompt: suspend () -> Boolean): ReminderPermission {
    restore()
    val permission = scheduler.requestPermission(prompt)
    return mutate {
      _state.value = _state.value.copy(permission = permission)
      if (permission != ReminderPermission.Granted) {
        // Never leave the toggle on over a queue that can't exist.
        write(reminder.copy(isEnabled = false))
      } else {
        write(reminder.copy(isEnabled = true), practisedToday)
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
  suspend fun setTime(hour: Int, minute: Int, practisedToday: Boolean) {
    restore()
    mutate {
      val updated = reminder.withTime(hour, minute)
      if (updated != reminder) write(updated, practisedToday)
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
  suspend fun reschedule(practisedToday: Boolean) {
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
      pushQueue(practisedToday, keepDue = true)
    }
  }

  // MARK: - Internals

  /** Runs [block] under [mutationLock], to completion even if the caller is
   * cancelled — the persisted choice and the system queue must agree. */
  private suspend fun <T> mutate(block: suspend () -> T): T =
    withContext(NonCancellable) { mutationLock.withLock { block() } }

  private suspend fun write(updated: DailyReminder, practisedToday: Boolean = false) {
    _state.value = _state.value.copy(reminder = updated)
    blob.writeQuietly(StoreJson.encodeToString(DailyReminder.serializer(), updated))
    if (updated.isEnabled) {
      pushQueue(practisedToday)
    } else {
      scheduler.clearQueue()
    }
  }

  /**
   * Rebuilds the system queue from now.
   *
   * @param keepDue keep an occurrence whose minute has passed but whose
   *   delivery window ([ReminderSchedule.deliveryWindow]) hasn't, unless its
   *   day already had its nudge. The alarm is inexact: at 01:56 a 01:55 nudge
   *   may still be pending, and rebuilding strictly after now replaced it with
   *   tomorrow's — opening DEEP inside the window cost the member today's
   *   nudge (QA round 3, B24). Only the lifecycle rebuild ([reschedule])
   *   keeps it; an explicit change of setting ([enable], [setTime]) never
   *   fires a minute already behind the member.
   */
  private suspend fun pushQueue(practisedToday: Boolean, keepDue: Boolean = false) {
    val now = ZonedDateTime.ofInstant(clock.instant(), zone())
    val from = if (keepDue) now.minus(ReminderSchedule.deliveryWindow) else now
    val today = now.toLocalDate()
    val queue = ReminderSchedule
      .occurrences(after = from, reminder = reminder, practisedToday = false, limit = ReminderSchedule.horizon + 2)
      // A day is done either way: practised today, or already nudged once.
      .filterNot { (practisedToday && it.toLocalDate() == today) || reminder.postedOn(it.toLocalDate()) }
      .take(ReminderSchedule.horizon)
    scheduler.replaceQueue(queue)
  }
}
