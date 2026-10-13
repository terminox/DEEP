package io.appbeyond.freelance.deep.feature.reminders.model

import kotlinx.serialization.Serializable

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
 * the same keys iOS writes.
 */
@Serializable
data class DailyReminder(
  val isEnabled: Boolean,
  val hour: Int,
  val minute: Int,
) {

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
