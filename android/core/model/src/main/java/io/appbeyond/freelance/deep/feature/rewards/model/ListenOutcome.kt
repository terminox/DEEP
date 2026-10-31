package io.appbeyond.freelance.deep.feature.rewards.model

/**
 * How many track hearts a day has earned, against its allowance.
 *
 * Ported from `ListenTally` in Deep/Deep/Features/Rewards/RewardsRemote.swift.
 *
 * @property dayKey the local day the listen counted toward ("YYYY-MM-DD").
 */
data class ListenTally(
  val dayKey: String,
  val earned: Int,
  val perDay: Int,
) {
  val isComplete: Boolean get() = earned >= perDay
}

/**
 * The server's answer to one listen report (`POST /me/sound/listens`).
 *
 * Ported from `ListenOutcome` in Deep/Deep/Features/Rewards/RewardsRemote.swift.
 *
 * @property judged whether the server placed the listen on a day at all. False
 *   when it finished too long ago (or too far ahead) to judge — nothing
 *   granted, nothing to retry.
 * @property granted whether this listen earned its heart.
 * @property cappedBy why it didn't: [AwardCap.DUPLICATE] (this track already
 *   counted today), [AwardCap.KIND_CAP] (today's track hearts are all in),
 *   [AwardCap.DAILY_CAP] (the day's overall hearts ceiling).
 * @property tally the day's track-heart tally; null from older servers and
 *   unjudged listens.
 * @property grant the settled grant for the ledger and garden — deltas plus
 *   the server's absolute figures. Null only when the response carried nothing
 *   to apply.
 */
data class ListenOutcome(
  val judged: Boolean,
  val granted: Boolean,
  val cappedBy: AwardCap? = null,
  val tally: ListenTally? = null,
  val grant: AwardGrant? = null,
) {
  companion object {
    /** A listen the server received but did not place — too old, or an answer
     * that couldn't be read. Nothing to apply, nothing to say, nothing to retry. */
    val Unjudged = ListenOutcome(judged = false, granted = false)
  }
}
