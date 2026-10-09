package io.appbeyond.freelance.deep.feature.rewards.model

/**
 * Client mirrors of the server's award rules (`deep-api/src/lib/awardRules.ts`)
 * — only the ones the UI needs to promise honestly before the server has
 * answered. The server remains the authority; these gates only stop the app
 * promising what can never be granted.
 *
 * Ported from `RewardRules` in Deep/Deep/Features/Rewards/AwardGrant.swift,
 * plus the daily hearts cap iOS keeps as `HeartLedger.dailyEarnCeiling`.
 */
object RewardRules {
  /** How many DEEP Sessions can earn per day (`SESSION_COMPLETED.perDay`).
   * The completion beat's optimistic heart is gated on this so it never
   * promises a fifth heart the practice sync will not deliver. */
  const val deepSessionDailyLimit = 4

  /** The most hearts one day can hand over, across every award kind
   * (`DAILY_HEARTS_CAP`). A ceiling, not a target: the day fills up and then
   * rests, so practice never turns into farming. */
  const val dailyHeartsCap = 30
}
