package io.appbeyond.freelance.deep.feature.reminders.store

import java.time.ZonedDateTime

/** Whether this device will let DEEP speak up. */
enum class ReminderPermission {
  /** Not granted yet, and the prompt may still be available. */
  Unasked,
  Granted,

  /**
   * Refused, or switched off later in the system's settings. Asking again
   * shows nothing — only Settings can undo it, so the UI has to say so.
   */
  Denied,
}

/**
 * Putting the daily nudge on the system's calendar. Named for the capability
 * so the real one and the test double can both be honest about what they are.
 *
 * Ported from `ReminderScheduling` in
 * Deep/Deep/Features/Reminders/Services/ReminderScheduling.swift, with two
 * Android differences:
 * - **Asking needs a screen.** `POST_NOTIFICATIONS` can only be requested from
 *   an activity, so [requestPermission] is handed the screen's [prompt]
 *   instead of presenting one itself.
 * - **Occurrences carry no copy.** iOS bakes each notification's words in
 *   when it is queued, and so rebuilds the queue on a language change; the
 *   Android alarm resolves its words in the chosen language as it fires.
 */
interface ReminderScheduling {

  /** The system's current answer, without prompting. */
  suspend fun permission(): ReminderPermission

  /**
   * Prompts if the system will still prompt; returns the settled state
   * either way.
   *
   * @param prompt shows the system permission dialog and returns whether it
   *   was granted.
   */
  suspend fun requestPermission(prompt: suspend () -> Boolean): ReminderPermission

  /** Replaces DEEP's whole reminder schedule with exactly these occurrences. */
  suspend fun replaceQueue(occurrences: List<ZonedDateTime>)

  suspend fun clearQueue()
}

/**
 * Records what it was asked to do instead of doing it, so previews stay
 * hermetic and tests can assert on the queue.
 *
 * @param grantsWhenAsked whether a prompt would be granted, for exercising the
 *   refused path.
 */
class MockReminderScheduler(
  @Volatile var currentPermission: ReminderPermission = ReminderPermission.Unasked,
  @Volatile var grantsWhenAsked: Boolean = true,
) : ReminderScheduling {

  @Volatile
  var queue: List<ZonedDateTime> = emptyList()
    private set

  override suspend fun permission(): ReminderPermission = currentPermission

  override suspend fun requestPermission(prompt: suspend () -> Boolean): ReminderPermission {
    if (currentPermission != ReminderPermission.Unasked) return currentPermission
    currentPermission = if (grantsWhenAsked) ReminderPermission.Granted else ReminderPermission.Denied
    return currentPermission
  }

  override suspend fun replaceQueue(occurrences: List<ZonedDateTime>) {
    queue = occurrences
  }

  override suspend fun clearQueue() {
    queue = emptyList()
  }
}
