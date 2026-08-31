#if DEBUG
import Foundation
import Observation

/// An in-memory `LoungeRadioPlaying` fake for previews.
///
/// State is whatever you set — no AVFoundation, no audio session, nothing
/// advances on its own. Mirrors `MockGlobalPauseAudioPlayer`'s role for the
/// meditation stream.
@Observable
final class MockLoungeRadioPlayer: LoungeRadioPlaying {
  var state: LoungeRadioState
  /// The last offset `join` was asked for, so a preview can assert the lounge
  /// joined the broadcast rather than starting it over.
  private(set) var joinedOffset: TimeInterval = 0

  @ObservationIgnored var liveOffsetProvider: (() -> TimeInterval)?

  init(state: LoungeRadioState = .off) {
    self.state = state
  }

  func join(url: URL, at offset: TimeInterval) {
    joinedOffset = offset
    state = .onAir(isMuted: false)
  }

  func setMuted(_ muted: Bool) {
    guard case .onAir = state else { return }
    state = .onAir(isMuted: muted)
  }

  func stop() {
    state = .off
    joinedOffset = 0
  }
}

extension MockLoungeRadioPlayer {
  /// Mid-set, for the on-air lounge previews.
  static var onAir: MockLoungeRadioPlayer {
    MockLoungeRadioPlayer(state: .onAir(isMuted: false))
  }
}
#endif
