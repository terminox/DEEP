package io.appbeyond.freelance.deep.feature.rewards.model

/**
 * One settled award from the server, as every producer (practice sync, track
 * listens, the pause claim, peace messages) hands it to the shared ingest. It
 * carries both the granted *deltas* and the *absolute* post-award figures:
 * `HeartLedger.apply` and `GardenStore.apply` SET the absolutes when present,
 * so an optimistic credit is reconciled rather than double-counted.
 *
 * Ported from Deep/Deep/Features/Rewards/AwardGrant.swift, with the DTO fold
 * from RewardsRemote.swift as [fold].
 */
data class AwardGrant(
  // Deltas — what this award actually granted.

  val hearts: Int = 0,
  val sunlight: Int = 0,
  /** The plant the sunlight was credited to. */
  val plantId: String? = null,
  /** True when the day's hard hearts cap withheld the award entirely. */
  val heartsCapped: Boolean = false,

  // Absolutes — the server's post-award truth, when it sent one.

  val heartsBalance: Int? = null,
  val heartsEarned: Int? = null,
  val heartsGiven: Int? = null,
  val heartsEarnedToday: Int? = null,
  val heartsRemainingToday: Int? = null,
  /** The credited plant's lifetime sunlight after this award. */
  val plantSunlight: Int? = null,
  val plantStageIndex: Int? = null,
) {
  companion object {
    /**
     * Folds one or more award outcomes plus the sibling wallet/plant snapshots
     * into a single grant: deltas summed over the *granted* outcomes only,
     * absolutes taken from the snapshots, [heartsCapped] set only by a
     * `daily_cap` refusal (a kind cap or a duplicate is not "the day is
     * full"). The plant id prefers the snapshot's, else the first granted
     * outcome's.
     *
     * Null when the response carried nothing to apply at all: nothing granted,
     * nothing daily-capped, no wallet and no plant (older servers, or a
     * withheld award with no snapshots).
     */
    fun fold(
      outcomes: List<AwardOutcome>,
      wallet: WalletSummary?,
      plant: PlantProgress?,
    ): AwardGrant? {
      val granted = outcomes.filter { it.granted }
      val capped = outcomes.any { it.cappedBy == AwardCap.DAILY_CAP }
      if (granted.isEmpty() && !capped && wallet == null && plant == null) return null
      return AwardGrant(
        hearts = granted.sumOf { it.heartsGranted },
        sunlight = granted.sumOf { it.sunlightGranted },
        plantId = plant?.plantId ?: granted.firstNotNullOfOrNull { it.plantId },
        heartsCapped = capped,
        heartsBalance = wallet?.heartsBalance,
        heartsEarned = wallet?.heartsEarned,
        heartsGiven = wallet?.heartsGiven,
        heartsEarnedToday = wallet?.earnedToday,
        heartsRemainingToday = wallet?.remainingToday,
        plantSunlight = plant?.sunlight,
        plantStageIndex = plant?.currentStageIndex,
      )
    }
  }
}
