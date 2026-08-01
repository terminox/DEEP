import AVFoundation
import MediaPlayer
import Observation

/// The real Global Pause audio engine: a bare `AVPlayer` for the meditation
/// stream, over HTTP from the backend's `/media/` route.
///
/// "Cannot be paused" is enforced in three layers, because lock-screen and
/// headphone controls can pause an `AVPlayer` without any app UI involved:
/// 1. The protocol exposes no pause/seek/transport at all.
/// 2. Remote commands (pause, toggle, stop, scrubbing, skips) are intercepted
///    and refused while the meditation is live.
/// 3. `timeControlStatus` is observed — if playback stops mid-meditation for
///    any other reason (interruption end, stall, a command that slipped
///    through), the player re-seeks to the live edge via
///    `meditationOffsetProvider` (or resumes in place on a solo pass) and
///    plays again.
///
/// Owned per session presentation by the coordinator; never registered with
/// the shared `SoundPlaying` environment, so the mini player never docks it.
@MainActor
@Observable
final class GlobalPauseAudioPlayer: GlobalPauseAudioPlaying {
  private(set) var mode: GlobalPauseAudioMode = .idle
  private(set) var meditationElapsed: TimeInterval = 0

  @ObservationIgnored var meditationOffsetProvider: (() -> TimeInterval)?

  @ObservationIgnored private var meditationPlayer: AVPlayer?
  @ObservationIgnored private var meditationDuration: TimeInterval = 0

  @ObservationIgnored private var timeObserver: Any?
  @ObservationIgnored private var rateObservation: NSKeyValueObservation?
  @ObservationIgnored private var stallObserver: NSObjectProtocol?
  @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
  @ObservationIgnored private var commandTargets: [(MPRemoteCommand, Any)] = []
  @ObservationIgnored private var sessionConfigured = false

  // MARK: - Meditation

  func playMeditation(url: URL, startingAt offset: TimeInterval, duration: TimeInterval) {
    stopMeditation()

    // A latecomer past the end gets silence — the phase engine is already in
    // (or moments from) the feedback phase.
    guard offset < duration else {
      mode = .idle
      return
    }

    meditationDuration = duration
    let player = AVPlayer(playerItem: AVPlayerItem(url: url))
    meditationPlayer = player
    mode = .meditation
    meditationElapsed = max(0, offset)

    observeMeditation(player)
    interceptRemoteCommands()
    publishNowPlaying(elapsed: offset)

    configureSessionIfNeeded()
    let target = CMTime(seconds: max(0, offset), preferredTimescale: 600)
    player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
      player?.play()
    }
  }

  func realignMeditation(to offset: TimeInterval) {
    guard mode == .meditation, let meditationPlayer else { return }
    guard offset < meditationDuration else {
      stopMeditation()
      mode = .idle
      return
    }
    meditationElapsed = max(0, offset)
    let target = CMTime(seconds: max(0, offset), preferredTimescale: 600)
    meditationPlayer.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak meditationPlayer] _ in
      meditationPlayer?.play()
    }
  }

  // MARK: - Teardown

  func stop() {
    stopMeditation()
    mode = .idle
  }

  private func stopMeditation() {
    releaseRemoteCommands()
    clearNowPlaying()
    if let timeObserver, let meditationPlayer {
      meditationPlayer.removeTimeObserver(timeObserver)
    }
    timeObserver = nil
    rateObservation?.invalidate()
    rateObservation = nil
    if let stallObserver { NotificationCenter.default.removeObserver(stallObserver) }
    stallObserver = nil
    if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
    interruptionObserver = nil
    meditationPlayer?.pause()
    meditationPlayer?.replaceCurrentItem(with: nil)
    meditationPlayer = nil
    meditationElapsed = 0
    meditationDuration = 0
    if mode == .meditation { mode = .idle }
  }

  // MARK: - Meditation observation & recovery

  private func observeMeditation(_ player: AVPlayer) {
    let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      MainActor.assumeIsolated {
        guard let self, self.mode == .meditation else { return }
        self.meditationElapsed = time.seconds
        self.publishNowPlaying(elapsed: time.seconds)
      }
    }

    // Layer 3 of unpausable: anything that lands the player in `.paused`
    // mid-meditation gets pushed back onto the live edge. A tiny delay lets
    // legitimate teardown (`stop()`) win the race.
    rateObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
      Task { @MainActor [weak self] in
        guard let self, self.mode == .meditation,
              let player = self.meditationPlayer,
              player.timeControlStatus == .paused
        else { return }
        self.recoverToLiveEdge()
      }
    }

    stallObserver = NotificationCenter.default.addObserver(
      forName: AVPlayerItem.playbackStalledNotification,
      object: player.currentItem,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.recoverToLiveEdge() }
    }

    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] note in
      MainActor.assumeIsolated {
        guard let self,
              let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: raw) == .ended
        else { return }
        // Whether or not the system suggests resuming, the pause is live —
        // rejoin it at the current offset.
        self.recoverToLiveEdge()
      }
    }
  }

  private func recoverToLiveEdge() {
    guard mode == .meditation else { return }
    if let offset = meditationOffsetProvider?() {
      realignMeditation(to: offset)
    } else {
      meditationPlayer?.play()
    }
  }

  // MARK: - Remote commands (layer 2 of unpausable)

  private func interceptRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()
    let refused: [MPRemoteCommand] = [
      center.pauseCommand,
      center.togglePlayPauseCommand,
      center.stopCommand,
      center.changePlaybackPositionCommand,
      center.skipForwardCommand,
      center.skipBackwardCommand,
      center.nextTrackCommand,
      center.previousTrackCommand,
    ]
    commandTargets = refused.map { command in
      (command, command.addTarget { _ in .commandFailed })
    }
    // Play stays honest: it can only ever push toward the live edge.
    commandTargets.append((center.playCommand, center.playCommand.addTarget { [weak self] _ in
      MainActor.assumeIsolated { self?.recoverToLiveEdge() }
      return .success
    }))
  }

  private func releaseRemoteCommands() {
    for (command, target) in commandTargets {
      command.removeTarget(target)
    }
    commandTargets = []
  }

  // MARK: - Now Playing

  private func publishNowPlaying(elapsed: TimeInterval) {
    guard mode == .meditation else { return }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = [
      MPMediaItemPropertyTitle: "Global Pause",
      MPMediaItemPropertyArtist: "The world, breathing together",
      MPMediaItemPropertyPlaybackDuration: meditationDuration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
      MPNowPlayingInfoPropertyPlaybackRate: 1.0,
      MPNowPlayingInfoPropertyIsLiveStream: true,
    ]
  }

  private func clearNowPlaying() {
    if mode == .meditation {
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
  }

  // MARK: - Session

  private func configureSessionIfNeeded() {
    guard !sessionConfigured else { return }
    sessionConfigured = true
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
  }
}
