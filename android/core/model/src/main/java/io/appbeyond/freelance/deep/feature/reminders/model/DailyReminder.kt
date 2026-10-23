package io.appbeyond.freelance.deep.feature.reminders.model

import kotlinx.serialization.Serializable
import java.time.LocalDate

/**
 * The daily nudge's whole settings state: whether it's on, and what time of
 * day it arrives. Persisted as one JSON blob, matching how every other local
 * store in the app keeps its state.
 *
 * Ported from Deep/Deep/Features/Reminders/Models/DailyReminder.swift. iOS's
 * `pickerDate` / `setTime(from:)` exist to talk to a `DatePicker` bound to a
 * `Date`; Android's time picker hands back an hour and a minute, so
 * [withTime] is the whole of that glue.
 *
 * Persisted blob (`deep.reminder`): `{"isEnabled":true,"hour":21,"minute":0}` —
 * the same keys iOS writes — plus Android's `lastPostedDay` once a nudge has
 * gone out.
 */
@Serializable
data class DailyReminder(
  val isEnabled: Boolean,
  val hour: Int,
  val minute: Int,
  /**
   * The local day (ISO `yyyy-MM-dd`, always Gregorian) today's nudge was
   * posted on, or null. A day that already had its nudge never queues another,
   * so moving the time later the same evening arms tomorrow (QA round 2, B22).
   * Android-only: iOS re-queues today's later time and can nudge twice.
   */
  val lastPostedDay: String? = null,
) {

  /** Whether the nudge has already gone out on [day]. */
  fun postedOn(day: LocalDate): Boolean = lastPostedDay == day.toString()

  /** The same switch at another clock face. */
  fun withTime(hour: Int, minute: Int): DailyReminder = copy(hour = hour, minute = minute)

  companion object {
    /**
     * Off, at 21:00 — the quiet end of an ordinary evening.
     *
     * It makes no attempt to dodge a Global Pause. There can be several a
     * day, at times an admin moves, written on Bangkok's clock; this nudge
     * runs on the member's own. No default hour could dodge them, and for
     * anyone outside Asia this one never did.
     */
    val initial = DailyReminder(isEnabled = false, hour = 21, minute = 0)
  }
}
