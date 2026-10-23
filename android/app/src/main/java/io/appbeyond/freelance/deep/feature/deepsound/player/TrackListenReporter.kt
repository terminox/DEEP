package io.appbeyond.freelance.deep.feature.deepsound.player

import android.util.Log
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.networking.ListenRequest
import io.appbeyond.freelance.deep.networking.SoundListensService
import io.appbeyond.freelance.deep.networking.apiCall
import io.appbeyond.freelance.deep.networking.toGrant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * The reward seam: told when a track has played through to its natural end.
 *
 * The Android twin of `StreamingSoundPlayer.trackFinished`. It lives beside the
 * service rather than the controller because only the service sees the end of a
 * track for certain — a controller in a backgrounded activity may be
 * disconnected when it happens. Skips, seeks and manual nexts never reach it;
 * `ListenRules.shouldReportListen` decides what counts.
 */
fun interface TrackListenReporting {
  fun trackFinished(trackId: String)
}

/**
 * Reports each finished track to deep-api, fire-and-forget — as iOS does in
 * `AppDependencies.swift`. A lost report costs at most one heart, the award
 * rules live server-side, and nothing on screen waits on the answer, so a
 * failure is logged and dropped rather than retried.
 *
 * The answer is not ignored, though: the award outcome and the wallet and
 * plant snapshots riding it are folded into one [AwardGrant] and handed to
 * [ingestAwards], so the heart ledger and the garden settle on the server's
 * post-award absolutes — the same seam the practice sync feeds.
 *
 * @param scope process-lifetime, so a report launched as the service winds down
 *   still completes.
 * A report is bound to the member who sent it. [ingestAwards] only checks that
 * *someone* is signed in, so a reply that settles after a sign-out and a new
 * sign-in would otherwise credit the previous member's award to the next one
 * (the listen path has no generation guard of its own, unlike the practice
 * journal's). The account id is captured when the report goes out and the grant
 * is dropped if [currentAccountId] has moved by the time it lands.
 *
 * @param currentAccountId the signed-in account's id, or null when signed out.
 * @param ingestAwards the shared award ingest (`AppDependencies.ingestAwards`).
 */
class ApiTrackListenReporter(
  private val service: SoundListensService,
  private val scope: CoroutineScope,
  private val currentAccountId: () -> String?,
  private val ingestAwards: suspend (AwardGrant) -> Unit,
) : TrackListenReporting {

  override fun trackFinished(trackId: String) {
    val sentFor = currentAccountId()
    scope.launch {
      val grant = try {
        apiCall { service.report(ListenRequest(trackId)) }.toGrant()
      } catch (cancelled: CancellationException) {
        throw cancelled
      } catch (dropped: Exception) {
        Log.i(TAG, "Listen report for $trackId was dropped: ${dropped.message}")
        return@launch
      }
      if (grant != null && currentAccountId() == sentFor) ingestAwards(grant)
    }
  }

  private companion object {
    const val TAG = "TrackListens"
  }
}
