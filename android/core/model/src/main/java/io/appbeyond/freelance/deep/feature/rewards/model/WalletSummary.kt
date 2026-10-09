package io.appbeyond.freelance.deep.feature.rewards.model

/**
 * The wallet as the server holds it — the absolute figures `HeartLedger`
 * hydrates from. Rides `GET /me/garden`, `GET /me/wallet` and every spend
 * response.
 *
 * Ported from `HeartsSummary` in Deep/Deep/Features/Rewards/AwardGrant.swift,
 * renamed after the server's own `WalletSummary` and its wire field names. As
 * on iOS (`HeartsSummary(dto:)`), the transport fills absent optional fields
 * with 0 / an empty map, and an absent `dailyCap` with
 * [RewardRules.dailyHeartsCap].
 */
data class WalletSummary(
  val heartsBalance: Int,
  val heartsEarned: Int,
  val heartsGiven: Int,
  val earnedToday: Int,
  val remainingToday: Int,
  val dailyCap: Int = RewardRules.dailyHeartsCap,
  /** Hearts this user has sent, by compassion category id. */
  val givenByCategory: Map<String, Int> = emptyMap(),
) {
  companion object {
    /** Mirrors the iOS `HeartsSummary.sample`, so mock-backed flows and
     * previews agree with the ledger's sample. */
    val sample = WalletSummary(
      heartsBalance = 2_450,
      heartsEarned = 2_768,
      heartsGiven = 318,
      earnedToday = 12,
      remainingToday = 18,
      dailyCap = 30,
      givenByCategory = mapOf("peace" to 104, "healthcare" to 96, "nature" to 71, "education" to 47),
    )

    /** A first-run wallet: hearts to give, nothing given, the day untouched. */
    val fresh = WalletSummary(
      heartsBalance = 120,
      heartsEarned = 120,
      heartsGiven = 0,
      earnedToday = 0,
      remainingToday = 30,
      dailyCap = 30,
      givenByCategory = emptyMap(),
    )
  }
}
