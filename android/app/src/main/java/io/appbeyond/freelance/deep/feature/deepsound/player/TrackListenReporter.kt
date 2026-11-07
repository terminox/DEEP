package io.appbeyond.freelance.deep.feature.deepsound.player

/**
 * The reward seam: told when a track has played through to its natural end.
 *
 * The Android twin of `StreamingSoundPlayer.trackFinished`. It lives beside the
 * service rather than the controller because only the service sees the end of a
 * track for certain — a controller in a backgrounded activity may be
 * disconnected when it happens. Skips, seeks and manual nexts never reach it;
 * `ListenRules.shouldReportListen` decides what counts.
 *
 * Non-suspending, since the player's listener calls it on the main thread: the
 * app stamps the finish there and hands it to the durable `ListenReporter` on
 * its own scope (`AppDependencies.trackListens`), so the listen is queued on
 * disk before anything touches the network.
 */
fun interface TrackListenReporting {
  fun trackFinished(trackId: String)
}
