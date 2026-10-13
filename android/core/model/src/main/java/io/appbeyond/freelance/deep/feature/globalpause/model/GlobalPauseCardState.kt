package io.appbeyond.freelance.deep.feature.globalpause.model

import java.time.Instant

/**
 * The three faces of the Global Pause card: resting on the schedule line,
 * counting down the final lead before the meditation, or live. Computed by the
 * session (which owns the clock and the boundaries); rendered by the card.
 *
 * Ported from `GlobalPauseCardState` in GlobalPauseSession.swift, with one
 * shape change: iOS carries the schedule line as finished copy; here it is the
 * instant it names, and the card words it ([PauseScheduleLine]) in the
 * member's language as it draws.
 */
sealed interface GlobalPauseCardState {

  /** At rest. [next] is the next meditation, or null for the resting line
   * ("Breathe with the world, together") when there is nothing to name. */
  data class Off(val next: Instant?) : GlobalPauseCardState

  /** Inside the final lead: "Live in 13:44" ticks down to [target]. */
  data class Countdown(val target: Instant) : GlobalPauseCardState

  data object Live : GlobalPauseCardState
}

/** Which country this device says it is in, as the server will accept it. */
object PauseCountry {

  private val ISO_ALPHA_2 = Regex("^[A-Z]{2}$")

  /**
   * The region code uppercased, or null unless it is ISO-3166 alpha-2 — the
   * server's zod schema refuses anything else, and a refused heartbeat would
   * cost the member their attendance. A UN M.49 numeric region ("419") or an
   * empty region simply goes unsent.
   */
  fun normalize(region: String?): String? =
    region?.uppercase()?.takeIf { ISO_ALPHA_2.matches(it) }
}
