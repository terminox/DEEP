package io.appbeyond.freelance.deep.feature.rewards

import io.appbeyond.freelance.deep.feature.compassion.store.HeartLedger
import io.appbeyond.freelance.deep.feature.globalpause.model.GlobalPauseRewardSnapshot
import io.appbeyond.freelance.deep.feature.globalpause.store.GlobalPauseSession
import io.appbeyond.freelance.deep.feature.mindgarden.store.GardenStore
import io.appbeyond.freelance.deep.feature.practice.store.PracticeJournal
import io.appbeyond.freelance.deep.feature.rewards.model.RewardReceipt
import io.appbeyond.freelance.deep.feature.rewards.store.ContinuityWitness

/**
 * The books for a Global Pause night's ending — the twin of [PracticeRewards]
 * for the pause, and the Android home of what iOS's session controller and
 * `GlobalPauseCompletionView` read off the shared stores by hand.
 *
 * Global Pause awards are server-settled, so unlike a DEEP Session there is no
 * optimistic credit: [snapshot] freezes the books as the meditation ends, the
 * claim and any first-message award reach the ledger and garden through the
 * shared ingest, and [receipt] reads what they hold once the claim settles.
 */
class PauseNightRewards(
  private val session: GlobalPauseSession,
  private val journal: PracticeJournal,
  private val ledger: HeartLedger,
  private val garden: GardenStore,
  private val witness: ContinuityWitness,
) {

  /** The books as they stand right now, before the claim moves them. */
  suspend fun snapshot(): GlobalPauseRewardSnapshot {
    garden.restore()
    return GlobalPauseRewardSnapshot(
      garden = garden.state.value.growth,
      heartBalance = ledger.state.value.balance,
      heartsEarnedToday = ledger.heartsEarnedToday,
      continuityWitnessedToday = witness.hasWitnessedToday(),
    )
  }

  /**
   * Lets the journal hydrate — at most [PracticeRewards.HYDRATION_TIMEOUT] —
   * so the rhythm the ending shows is the account's real one. The visit runs
   * this alongside settling tonight's claim.
   */
  suspend fun hydrate() {
    journal.awaitHydration(PracticeRewards.HYDRATION_TIMEOUT)
  }

  /**
   * Folds the night onto [before]. The rhythm is read from the journal now,
   * after an eligible claim has already kept the day there; a journal never
   * hydrated leaves the beat unknown, so it rests.
   */
  suspend fun receipt(before: GlobalPauseRewardSnapshot): RewardReceipt {
    journal.restore()
    val night = session.state.value
    return RewardReceipt.pauseNight(
      before = before,
      awards = listOfNotNull(night.pauseAward, night.messageAward),
      gardenAfter = garden.state.value.growth,
      heartBalanceAfter = ledger.state.value.balance,
      heartsEarnedTodayAfter = ledger.heartsEarnedToday,
      continuity = journal.continuityTransition(),
      continuityKnown = journal.isHydrated,
      attendanceMissed = night.pauseAwardMissed,
      attendancePending = night.pauseAwardPending,
    )
  }

  /** Stamps today's continuity beat as the ritual reaches it. */
  suspend fun witnessContinuity() {
    witness.witnessToday()
  }
}
