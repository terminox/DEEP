#if DEBUG
import Foundation
import Observation

/// An in-memory `GlobalPauseAudioPlaying` fake for previews.
///
/// State is whatever you set — no AVFoundation, no audio session, nothing
/// advances on its own. Mirrors `MockSoundPlayer`'s role for the shared player.
@Observable
final class MockGlobalPauseAudioPlayer: GlobalPauseAudioPlaying {
  var mode: GlobalPauseAudioMode
  var meditationElapsed: TimeInterval

  @ObservationIgnored var meditationOffsetProvider: (() -> TimeInterval)?

  init(mode: GlobalPauseAudioMode = .idle, meditationElapsed: TimeInterval = 0) {
    self.mode = mode
    self.meditationElapsed = meditationElapsed
  }

  func playMeditation(url: URL, startingAt offset: TimeInterval, duration: TimeInterval) {
    mode = .meditation
    meditationElapsed = offset
  }

  func realignMeditation(to offset: TimeInterval) {
    meditationElapsed = offset
  }

  func stop() {
    mode = .idle
    meditationElapsed = 0
  }
}

extension MockGlobalPauseAudioPlayer {
  /// Mid-meditation, for the live-phase screens.
  static var meditating: MockGlobalPauseAudioPlayer {
    MockGlobalPauseAudioPlayer(mode: .meditation, meditationElapsed: 184)
  }
}
#endif
