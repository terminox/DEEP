package io.appbeyond.freelance.deep.feature.rewards

import io.appbeyond.freelance.deep.feature.compassion.store.HeartLedger
import io.appbeyond.freelance.deep.feature.mindgarden.store.GardenStore
import io.appbeyond.freelance.deep.feature.practice.store.PracticeJournal
import io.appbeyond.freelance.deep.feature.rewards.model.RewardReceipt
import io.appbeyond.freelance.deep.feature.rewards.model.RewardRules
import io.appbeyond.freelance.deep.feature.rewards.store.ContinuityWitness
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Turns a finished DEEP Session into the [RewardReceipt] its ending ritual
 * plays: records the practice, credits the optimistic heart and sunlight, and
 * freezes both sides of every number before the first reward screen shows.
 *
 * Ported step for step from `DeepSessionCoordinatorView.finishSession()` on
 * iOS, which does this inline in the view. Here it is one object the app
 * builds once, so the bookkeeping is testable without a screen and the
 * session coordinator only has to ask for a receipt:
 *
 * 1. Freeze the before-values — the garden's growth, the heart balance,
 *    today's earned hearts, the practice streak, and whether today's
 *    continuity beat was already witnessed.
 * 2. Record the completion in the journal (unsynced, stamped now).
 * 3. Only the first [RewardRules.deepSessionDailyLimit] sessions of a day
 *    earn: a heart, clamped to what's left of the day's ceiling.
 * 4. Hearts and sunlight travel as one pair — sunlight is credited only when
 *    the heart was, matching the server contract.
 * 5. Build the receipt from the stores' live after-values.
 * 6. Offer the journal to the backend on the app scope, not awaited — the
 *    ritual never waits on the network, and the push's absolutes reconcile
 *    the optimistic credits behind it through the shared award ingest.
 *
 * Differences from iOS:
 * - The stores restore their persisted state on first use, so step 1 restores
 *   the journal and the garden before reading them — otherwise a first session
 *   right after a cold launch would freeze an empty streak.
 * - The bookkeeping runs [NonCancellable]: the session screen leaving
 *   mid-completion must not record the practice without its heart, or credit
 *   the heart without its sunlight.
 * - Completions are serialised, so two near-simultaneous calls can never
 *   interleave their before and after values. (iOS guards with `didRecord`.)
 *
 * @param scope process-lifetime, so the push outlives the session screen.
 */
class PracticeRewards(
  private val journal: PracticeJournal,
  private val ledger: HeartLedger,
  private val garden: GardenStore,
  private val witness: ContinuityWitness,
  private val scope: CoroutineScope,
) {

  private val completing = Mutex()

  /**
   * Records a finished session of [durationSeconds] titled [title] and
   * returns the receipt for its ending ritual.
   */
  suspend fun complete(title: String, durationSeconds: Int): RewardReceipt = withContext(NonCancellable) {
    completing.withLock {
      // Frozen before the ritual runs: whichever practice reaches the beat
      // first today is the one that shows it.
      val continuityWitnessedToday = witness.hasWitnessedToday()
      journal.restore()
      garden.restore()

      val gardenBefore = garden.state.value.growth
      val heartBalanceBefore = ledger.state.value.balance
      val heartsEarnedTodayBefore = ledger.heartsEarnedToday
      val continuityBefore = journal.currentStreakDays()

      journal.record(title = title, durationSeconds = durationSeconds)

      val isRewardEligible = journal.completionsToday() <= RewardRules.deepSessionDailyLimit
      val heartsAwarded = if (isRewardEligible) ledger.earn() else 0
      // DEEP Session rewards travel as one pair. If the heart ceiling
      // withholds this award, sunlight rests too, matching the server.
      val sunlightAwarded = if (heartsAwarded > 0) garden.creditSunlight(1) else 0

      val receipt = RewardReceipt(
        gardenBefore = gardenBefore,
        gardenAfter = garden.state.value.growth,
        sunlightAwarded = sunlightAwarded,
        heartBalanceBefore = heartBalanceBefore,
        heartBalanceAfter = ledger.state.value.balance,
        heartsEarnedTodayBefore = heartsEarnedTodayBefore,
        heartsEarnedTodayAfter = ledger.heartsEarnedToday,
        heartsAwarded = heartsAwarded,
        continuityBefore = continuityBefore,
        continuityAfter = journal.currentStreakDays(),
        continuityWitnessedToday = continuityWitnessedToday,
      )

      scope.launch { journal.push() }
      receipt
    }
  }

  /**
   * Stamps today's continuity beat as witnessed. The ritual calls this as the
   * Continuity step appears — not when the receipt is built — so an ending the
   * member walks away from doesn't spend the day's one witnessing.
   */
  suspend fun witnessContinuity() {
    witness.witnessToday()
  }
}
