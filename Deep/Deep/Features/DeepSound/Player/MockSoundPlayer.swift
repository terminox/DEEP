#if DEBUG
import Foundation
import Observation

/// An in-memory `SoundPlaying` fake for previews and tests.
///
/// State is whatever you set — no timer, no playback, no side effects. Transport
/// methods mutate state synchronously so the UI reacts, but nothing advances on
/// its own. Use the static fixtures (`idle`, `playing`) for the common cases.
@Observable
final class MockSoundPlayer: SoundPlaying {
  var queue: [SoundQueueEntry]
  var index: Int
  var isPlaying: Bool
  var elapsed: TimeInterval
  var volume: Double

  init(
    queue: [SoundQueueEntry] = [],
    index: Int = 0,
    isPlaying: Bool = false,
    elapsed: TimeInterval = 0,
    volume: Double = 0.6
  ) {
    self.queue = queue
    self.index = index
    self.isPlaying = isPlaying
    self.elapsed = elapsed
    self.volume = volume
  }

  var collection: SoundCollection? {
    queue.indices.contains(index) ? queue[index].collection : nil
  }
  var currentTrack: SoundTrack? {
    queue.indices.contains(index) ? queue[index].track : nil
  }
  var hasTrack: Bool { currentTrack != nil }
  var duration: TimeInterval { currentTrack?.duration ?? 0 }
  var progress: Double {
    guard duration > 0 else { return 0 }
    return min(1, max(0, elapsed / duration))
  }

  func play(_ entries: [SoundQueueEntry], at index: Int) {
    self.queue = entries
    self.index = min(max(0, index), max(0, entries.count - 1))
    elapsed = 0
    isPlaying = true
  }

  func togglePlayPause() {
    guard hasTrack else { return }
    isPlaying.toggle()
  }

  func next() {
    guard !queue.isEmpty else { return }
    index = (index + 1) % queue.count
    elapsed = 0
  }

  func previous() {
    guard !queue.isEmpty else { return }
    if elapsed > 3 {
      elapsed = 0
    } else {
      index = (index - 1 + queue.count) % queue.count
      elapsed = 0
    }
  }

  func seek(toProgress fraction: Double) {
    elapsed = min(max(0, fraction), 1) * duration
  }
}

extension MockSoundPlayer {
  /// Nothing loaded — the default home state.
  static var idle: MockSoundPlayer { MockSoundPlayer() }

  /// Mid-track on a collection, for player-centric screens.
  static var playing: MockSoundPlayer {
    let player = MockSoundPlayer()
    player.play(SoundLibrary.sleep[0])
    player.elapsed = min(42, player.duration)
    return player
  }
}
#endif
