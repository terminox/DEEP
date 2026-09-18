package io.appbeyond.freelance.deep.feature.reminders.model

/**
 * The daily nudge's whole settings state: whether it's on, and what time of
 * day it arrives. Persisted as one JSON blob, matching how every other local
 * store in the app keeps its state.
 *
 * Ported from Deep/Deep/Features/Reminders/Models/DailyReminder.swift. The
 * SwiftUI-facing conveniences (`pickerDate`, `setTime`, and the `DatePicker`
 * `DateComponents` binding) stay on the iOS side — they exist to talk to
 * `DatePicker`/`Calendar.current` and have no Android counterpart yet. Only
 * the persisted state travels here; the platform layer that lands with
 * reminders in week 5 will grow its own Android-native time-picker glue.
 */
data class DailyReminder(
  val isEnabled: Boolean,
  val hour: Int,
  val minute: Int,
) {
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
