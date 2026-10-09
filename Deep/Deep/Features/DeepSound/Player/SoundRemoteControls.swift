import MediaPlayer
import UIKit

/// DEEP Sound on the lock screen, Control Center, headphones and CarPlay: the
/// Now Playing card and the remote commands that drive the player.
///
/// The commands are shared app-wide, and Global Pause registers its own while
/// it plays, so DEEP Sound only holds them between `attach` and `detach` — and
/// `detach` removes only the targets it added.
@MainActor
final class SoundRemoteControls {
  /// What each remote command does. The player hands these over on `attach`.
  struct Actions {
    var play: () -> Void
    var pause: () -> Void
    var togglePlayPause: () -> Void
    var next: () -> Void
    var previous: () -> Void
    var seek: (TimeInterval) -> Void
    var setRepeatMode: (RepeatMode) -> Void
    var setShuffled: (Bool) -> Void
  }

  /// Turns a collection's artwork URL into an image for the Now Playing card.
  private let loadArtwork: (URL) async -> UIImage?
  private var targets: [(MPRemoteCommand, Any)] = []
  private var artwork: (url: URL, image: MPMediaItemArtwork)?
  /// The artwork the card on screen should carry — a late download for an
  /// earlier collection must not land on it.
  private var cardArtworkURL: URL?
  private var artworkTask: Task<Void, Never>?

  var isAttached: Bool { !targets.isEmpty }

  init(loadArtwork: @escaping (URL) async -> UIImage?) {
    self.loadArtwork = loadArtwork
  }

  // MARK: - Commands

  func attach(_ actions: Actions) {
    guard !isAttached else { return }
    let center = MPRemoteCommandCenter.shared()
    add(center.playCommand) { actions.play() }
    add(center.pauseCommand) { actions.pause() }
    add(center.togglePlayPauseCommand) { actions.togglePlayPause() }
    add(center.nextTrackCommand) { actions.next() }
    add(center.previousTrackCommand) { actions.previous() }
    for command: MPRemoteCommand in [
      center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
      center.nextTrackCommand, center.previousTrackCommand,
      center.changePlaybackPositionCommand, center.changeRepeatModeCommand,
      center.changeShuffleModeCommand,
    ] {
      command.isEnabled = true
    }

    targets.append((center.changePlaybackPositionCommand, center.changePlaybackPositionCommand.addTarget { event in
      guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
      MainActor.assumeIsolated { actions.seek(event.positionTime) }
      return .success
    }))
    targets.append((center.changeRepeatModeCommand, center.changeRepeatModeCommand.addTarget { event in
      guard let event = event as? MPChangeRepeatModeCommandEvent else { return .commandFailed }
      let mode: RepeatMode = switch event.repeatType {
      case .one: .one
      case .all: .all
      default: .off
      }
      MainActor.assumeIsolated { actions.setRepeatMode(mode) }
      return .success
    }))
    targets.append((center.changeShuffleModeCommand, center.changeShuffleModeCommand.addTarget { event in
      guard let event = event as? MPChangeShuffleModeCommandEvent else { return .commandFailed }
      MainActor.assumeIsolated { actions.setShuffled(event.shuffleType != .off) }
      return .success
    }))
  }

  /// Hands the commands and the Now Playing card back — another feature owns
  /// the audio now.
  func detach() {
    for (command, target) in targets {
      command.removeTarget(target)
    }
    targets = []
    artworkTask?.cancel()
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }

  private func add(_ command: MPRemoteCommand, _ action: @escaping @MainActor () -> Void) {
    targets.append((command, command.addTarget { _ in
      MainActor.assumeIsolated { action() }
      return .success
    }))
  }

  // MARK: - Now Playing

  /// Rewrites the Now Playing card. Called on track changes, play/pause and
  /// seeks — between those the system runs the clock on from `rate`.
  func publish(
    track: SoundTrack?,
    collection: SoundCollection?,
    elapsed: TimeInterval,
    isPlaying: Bool,
    repeatMode: RepeatMode,
    isShuffled: Bool
  ) {
    guard isAttached else { return }
    let center = MPRemoteCommandCenter.shared()
    center.changeRepeatModeCommand.currentRepeatType = switch repeatMode {
    case .off: .off
    case .all: .all
    case .one: .one
    }
    center.changeShuffleModeCommand.currentShuffleType = isShuffled ? .items : .off

    guard let track else {
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      return
    }
    var info: [String: Any] = [
      MPMediaItemPropertyTitle: track.title,
      MPMediaItemPropertyPlaybackDuration: track.duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
      MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
      MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
    ]
    if let collection {
      info[MPMediaItemPropertyAlbumTitle] = collection.title
    }
    cardArtworkURL = collection?.imageURL
    if let artwork, artwork.url == cardArtworkURL {
      info[MPMediaItemPropertyArtwork] = artwork.image
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info

    if let url = collection?.imageURL, artwork?.url != url {
      fetchArtwork(url)
    }
  }

  /// Loads the artwork once per collection and adds it to whatever card is
  /// showing when it lands, if that card is still for the same collection.
  private func fetchArtwork(_ url: URL) {
    artworkTask?.cancel()
    artworkTask = Task { [weak self, loadArtwork] in
      guard let image = await loadArtwork(url), !Task.isCancelled, let self else { return }
      let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
      self.artwork = (url, artwork)
      guard self.isAttached, self.cardArtworkURL == url,
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo
      else { return }
      info[MPMediaItemPropertyArtwork] = artwork
      MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
  }
}
