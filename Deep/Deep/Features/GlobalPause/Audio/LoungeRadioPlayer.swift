import AVFoundation
import MediaPlayer
import Observation
import os

/// The real lounge radio: a bare `AVPlayer` streaming the lobby track over HTTP
/// from the backend's `/media/` route, joined at whatever offset the synced
/// clock says the set has reached.
///
/// Recovery keeps it a broadcast rather than a recording. A stall or an audio
/// interruption re-seeks to the live edge through `liveOffsetProvider`, so
/// coming back from a phone call drops you where the room actually is, not
/// where you left it.
///
/// Lock-screen and headphone controls are wired to *mute*, not to transport:
/// pause silences the set while it keeps running underneath, and play rejoins
/// it live. That is the same thing tapping the ON AIR pill does, so the two
/// surfaces can never disagree about what the member asked for.
///
/// Owned by the coordinator and injected into the lounge, never registered with
/// the shared `SoundPlaying` environment, so the mini player never docks it.
@MainActor
@Observable
final class LoungeRadioPlayer: LoungeRadioPlaying {
  private(set) var state: LoungeRadioState = .off

  @ObservationIgnored var liveOffsetProvider: (() -> TimeInterval)?

  @ObservationIgnored private var player: AVPlayer?
  @ObservationIgnored private var currentURL: URL?

  @ObservationIgnored private let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Deep", category: "LoungeRadio"
  )

  @ObservationIgnored private var itemStatusObservation: NSKeyValueObservation?
  @ObservationIgnored private var endObserver: NSObjectProtocol?
  @ObservationIgnored private var stallObserver: NSObjectProtocol?
  @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
  @ObservationIgnored private var commandTargets: [(MPRemoteCommand, Any)] = []
  @ObservationIgnored private var sessionConfigured = false

  /// How far the playhead may already be from a requested offset before the
  /// request counts as a real realign rather than a re-render asking for what
  /// is already playing. Comfortably wider than one poll's drift.
  private let realignTolerance: TimeInterval = 3

  // MARK: - Joining

  func join(url: URL, at offset: TimeInterval) {
    // A re-render asking for what is already playing must not restart the track.
    if case .onAir = state, url == currentURL, let player,
       abs(player.currentTime().seconds - offset) < realignTolerance {
      return
    }

    let wasMuted = isMuted
    teardownPlayer()

    let fresh = AVPlayer(playerItem: AVPlayerItem(url: url))
    fresh.isMuted = wasMuted
    player = fresh
    currentURL = url
    state = .onAir(isMuted: wasMuted)

    observe(fresh)
    interceptRemoteCommands()
    configureSessionIfNeeded()
    publishNowPlaying(elapsed: offset)

    let target = CMTime(seconds: max(0, offset), preferredTimescale: 600)
    fresh.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak fresh] _ in
      fresh?.play()
    }
  }

  func setMuted(_ muted: Bool) {
    guard case .onAir = state else { return }
    player?.isMuted = muted
    state = .onAir(isMuted: muted)
    // Unmuting rejoins the room rather than resuming a broadcast that has moved
    // on without us.
    if !muted { recoverToLiveEdge() }
  }

  // MARK: - Teardown

  func stop() {
    teardownPlayer()
    currentURL = nil
    state = .off
  }

  private var isMuted: Bool {
    if case .onAir(let muted) = state { return muted }
    return false
  }

  private func teardownPlayer() {
    releaseRemoteCommands()
    clearNowPlaying()
    itemStatusObservation?.invalidate()
    itemStatusObservation = nil
    for observer in [endObserver, stallObserver, interruptionObserver].compactMap({ $0 }) {
      NotificationCenter.default.removeObserver(observer)
    }
    endObserver = nil
    stallObserver = nil
    interruptionObserver = nil
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
  }

  // MARK: - Observation & recovery

  private func observe(_ player: AVPlayer) {
    itemStatusObservation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard item.status == .failed else { return }
      let reason = item.error.map(String.init(describing:)) ?? "unknown error"
      Task { @MainActor [weak self] in
        self?.log.error("lounge track failed to load: \(reason, privacy: .public)")
        // Nothing is playing, so nothing should claim to be on air.
        self?.stop()
      }
    }

    // The set running out is the set ending: the session's boundary timer takes
    // the badge down at the same instant, and this releases the audio.
    endObserver = NotificationCenter.default.addObserver(
      forName: AVPlayerItem.didPlayToEndTimeNotification,
      object: player.currentItem,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.stop() }
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
        self.recoverToLiveEdge()
      }
    }
  }

  /// Re-seeks to wherever the room has got to and plays on. A muted set stays
  /// muted — it is still running, the member just isn't listening.
  private func recoverToLiveEdge() {
    guard case .onAir = state, let player else { return }
    guard let offset = liveOffsetProvider?() else {
      player.play()
      return
    }
    let target = CMTime(seconds: max(0, offset), preferredTimescale: 600)
    player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
      player?.play()
    }
    publishNowPlaying(elapsed: offset)
  }

  // MARK: - Remote commands (wired to mute, not transport)

  private func interceptRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()
    let mute: [MPRemoteCommand] = [center.pauseCommand, center.stopCommand]
    commandTargets = mute.map { command in
      (command, command.addTarget { [weak self] _ in
        MainActor.assumeIsolated { self?.setMuted(true) }
        return .success
      })
    }
    commandTargets.append((center.playCommand, center.playCommand.addTarget { [weak self] _ in
      MainActor.assumeIsolated { self?.setMuted(false) }
      return .success
    }))
    commandTargets.append(
      (center.togglePlayPauseCommand, center.togglePlayPauseCommand.addTarget { [weak self] _ in
        MainActor.assumeIsolated { self.map { $0.setMuted(!$0.isMuted) } }
        return .success
      })
    )
    // Nothing to scrub or skip to: it is one live set.
    let refused: [MPRemoteCommand] = [
      center.changePlaybackPositionCommand,
      center.skipForwardCommand,
      center.skipBackwardCommand,
      center.nextTrackCommand,
      center.previousTrackCommand,
    ]
    commandTargets += refused.map { command in
      (command, command.addTarget { _ in .commandFailed })
    }
  }

  private func releaseRemoteCommands() {
    for (command, target) in commandTargets {
      command.removeTarget(target)
    }
    commandTargets = []
  }

  // MARK: - Now Playing

  private func publishNowPlaying(elapsed: TimeInterval) {
    guard case .onAir = state else { return }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = [
      MPMediaItemPropertyTitle: "Fuku's Lounge",
      MPMediaItemPropertyArtist: "Live before the Global Pause",
      MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
      MPNowPlayingInfoPropertyPlaybackRate: 1.0,
      MPNowPlayingInfoPropertyIsLiveStream: true,
    ]
  }

  private func clearNowPlaying() {
    if case .onAir = state {
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
