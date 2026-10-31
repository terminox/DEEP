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
import java.time.Duration

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
 *    today's earned hearts, and whether today's continuity beat was already
 *    witnessed.
 * 2. Only the first [RewardRules.deepSessionDailyLimit] sessions of a day
 *    earn: a heart, clamped to what's left of the day's ceiling.
 * 3. Hearts and sunlight travel as one pair — sunlight is credited only when
 *    the heart was, matching the server contract.
 * 4. Record the completion in the journal (unsynced, stamped now), and offer
 *    it to the backend on the app scope, not awaited — the push's absolutes
 *    reconcile the optimistic credits behind it through the shared ingest.
 * 5. Wait up to [HYDRATION_TIMEOUT] for the journal's first pull, then read
 *    the rhythm across today's boundary ([PracticeJournal.continuityTransition]);
 *    a journal still unhydrated marks the beat unknown, so it rests.
 * 6. Build the receipt from those and the stores' after-values.
 *
 * Differences from iOS:
 * - The credit (steps 2–3) comes before the record (step 4). iOS records
 *   first, but there the record, the eligibility count and both credits run
 *   in one main-actor turn, so no push answer can land between them. Here
 *   the record suspends on its disk write; credited after it, a push answer
 *   landing in that write would already carry this heart and the credit
 *   would count it twice. Eligibility counts the session about to be
 *   recorded (`completionsToday() + 1`), the same number iOS reads after.
 * - The stores restore their persisted state on first use, so step 1 restores
 *   the journal and the garden before reading them — otherwise a first session
 *   right after a cold launch would read an empty garden.
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

      // Credited before the session is recorded. The record suspends on its
      // disk write, and a push started meanwhile (a foreground sync) can pick
      // the new session up: were its answer to land before the optimistic
      // credit, the server's absolutes would already include this heart and
      // the credit would count it twice. Unrecorded, no push can carry it, so
      // its award can only arrive after the credit and reconcile it.
      val isRewardEligible = journal.completionsToday() + 1 <= RewardRules.deepSessionDailyLimit
      val heartsAwarded = if (isRewardEligible) ledger.earn() else 0
      // DEEP Session rewards travel as one pair. If the heart ceiling
      // withholds this award, sunlight rests too, matching the server.
      val sunlightAwarded = if (heartsAwarded > 0) garden.creditSunlight(1) else 0
      val gardenAfter = garden.state.value.growth
      val heartBalanceAfter = ledger.state.value.balance
      val heartsEarnedTodayAfter = ledger.heartsEarnedToday

      journal.record(title = title, durationSeconds = durationSeconds)
      scope.launch { journal.push() }

      // Under the last exhale's settle, which the coordinator holds alongside
      // this, let the journal hydrate, so the rhythm the ending shows is the
      // account's real one rather than this install's partial memory (a fresh
      // sign-in would otherwise read 0 → 1).
      journal.awaitHydration(HYDRATION_TIMEOUT)
      val continuity = journal.continuityTransition()

      RewardReceipt(
        gardenBefore = gardenBefore,
        gardenAfter = gardenAfter,
        sunlightAwarded = sunlightAwarded,
        heartBalanceBefore = heartBalanceBefore,
        heartBalanceAfter = heartBalanceAfter,
        heartsEarnedTodayBefore = heartsEarnedTodayBefore,
        heartsEarnedTodayAfter = heartsEarnedTodayAfter,
        heartsAwarded = heartsAwarded,
        continuityBefore = continuity.before,
        continuityAfter = continuity.after,
        continuityWitnessedToday = continuityWitnessedToday,
        // Never hydrated: the beat rests rather than show a wrong number.
        continuityKnown = journal.isHydrated,
      )
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

  internal companion object {
    /** How long an ending waits for the journal's first pull before it
     * composes without the rhythm — iOS's `awaitHydration(timeout: .seconds(2))`. */
    val HYDRATION_TIMEOUT: Duration = Duration.ofSeconds(2)
  }
}
