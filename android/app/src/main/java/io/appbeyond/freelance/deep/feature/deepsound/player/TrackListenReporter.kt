package io.appbeyond.freelance.deep.feature.deepsound.player

import android.util.Log
import io.appbeyond.freelance.deep.networking.ListenRequest
import io.appbeyond.freelance.deep.networking.SoundListensService
import io.appbeyond.freelance.deep.networking.apiCall
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
 * @param scope process-lifetime, so a report launched as the service winds down
 *   still completes.
 */
class ApiTrackListenReporter(
  private val service: SoundListensService,
  private val scope: CoroutineScope,
) : TrackListenReporting {

  override fun trackFinished(trackId: String) {
    scope.launch {
      runCatching { apiCall { service.report(ListenRequest(trackId)) } }
        .onFailure { Log.i(TAG, "Listen report for $trackId was dropped: ${it.message}") }
    }
  }

  private companion object {
    const val TAG = "TrackListens"
  }
}
