package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseLiveSnapshot
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseSchedule
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessagesPage
import io.appbeyond.freelance.deep.feature.globalpause.model.PostedPeaceMessage
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant

/**
 * The server's answer to tonight's attendance claim (`POST /me/pause/award`).
 *
 * @property eligible whether the server counted the night — present through
 *   most of the meditation, by heartbeat coverage.
 * @property grant what it gave: null when ineligible, and null too for a
 *   night already claimed (the second visit of the same night still counts,
 *   with nothing fresh to grant).
 */
data class PauseAwardClaim(val eligible: Boolean, val grant: AwardGrant?)

/**
 * The backend seam for the Global Pause event: tonight's schedule, live
 * presence, peace messages, the reflection and the attendance claim.
 *
 * Ported from the `PauseEventRepository` protocol in
 * Deep/Deep/Features/GlobalPause/Models/PauseEventRepository.swift, plus the
 * claim iOS keeps on `RewardsRemote` — on Android each award producer owns
 * its own call (see `ApiRewardsRemote`).
 *
 * Implementations push every response's `serverNow` into the shared
 * [io.appbeyond.freelance.deep.feature.globalpause.model.SyncedClock] so the
 * phase engine keeps agreeing with the server. Failures are thrown; a network
 * failure is a [io.appbeyond.freelance.deep.auth.TransportFailure].
 */
interface PauseEventRemote {

  suspend fun schedule(): PauseSchedule

  suspend fun live(): PauseLiveSnapshot

  /**
   * Renews presence. Returns the caller's own server-resolved location
   * (privacy-rounded), null when the server couldn't place the IP.
   */
  suspend fun heartbeat(presenceId: String, countryIso: String?): PauseJoinPoint?

  /** Best-effort; failures are irrelevant — the server sweeps stale presence. */
  suspend fun leave(presenceId: String)

  suspend fun messages(limit: Int, cursor: String?): PeaceMessagesPage

  suspend fun postMessage(text: String, countryIso: String?, intention: String?): PostedPeaceMessage

  suspend fun submitReflection(intention: String?, mood: String?)

  suspend fun claimPauseAward(): PauseAwardClaim
}
