package io.appbeyond.freelance.deep.feature.deepsound.model

/** How a track stopped playing — the reason `shouldReportListen` needs. */
enum class Advance {
  /** Played through to the end on its own. */
  Natural,

  /** The listener skipped to another track. */
  Skip,

  /** The listener scrubbed within the same track. */
  Seek,
}

/**
 * The shared player's bookkeeping rules that have nothing to do with the
 * transport itself: whether a play counts as a "listen" for stats, and
 * whether swapping accounts should tear the player down.
 */
object ListenRules {
  /** A play is reported only when it ran its natural course — a skip or a
   * seek never counts as a listen — the track actually had audio to play,
   * and someone is signed in to attribute it to. */
  fun shouldReportListen(advance: Advance, playable: Boolean, signedIn: Boolean): Boolean =
    advance == Advance.Natural && playable && signedIn

  /** The player should reset whenever a *different* signed-in account takes
   * over. Never on first sign-in ([beforeAccountId] is `null`), and never
   * when the account didn't actually change. */
  fun shouldClearPlayer(beforeAccountId: String?, afterAccountId: String?): Boolean =
    beforeAccountId != null && afterAccountId != beforeAccountId
}
