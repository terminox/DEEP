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
  var queue: SoundQueue
  var isPlaying: Bool
  var elapsed: TimeInterval
  var volume: Double
  /// Whether another feature has taken the audio over since the last play.
  private(set) var hasYielded = false
  var repeatMode: RepeatMode {
    get { queue.repeatMode }
    set { queue.repeatMode = newValue }
  }
  var isShuffled: Bool {
    get { queue.isShuffled }
    set { queue.setShuffled(newValue, using: &generator) }
  }

  @ObservationIgnored private var generator = SystemRandomNumberGenerator()

  init(
    queue: SoundQueue = SoundQueue(canPlay: { _ in true }),
    isPlaying: Bool = false,
    elapsed: TimeInterval = 0,
    volume: Double = 0.6
  ) {
    self.queue = queue
    self.isPlaying = isPlaying
    self.elapsed = elapsed
    self.volume = volume
  }

  var collection: SoundCollection? { queue.current?.collection }
  var currentTrack: SoundTrack? { queue.current?.track }
  var hasTrack: Bool { currentTrack != nil }
  var duration: TimeInterval { currentTrack?.duration ?? 0 }
  var progress: Double {
    guard duration > 0 else { return 0 }
    return min(1, max(0, elapsed / duration))
  }

  func play(_ entries: [SoundQueueEntry], at index: Int?, shuffled: Bool) {
    queue = queue.replacing(with: entries, startingAt: index, shuffled: shuffled, using: &generator)
    elapsed = 0
    isPlaying = hasTrack
    hasYielded = false
  }

  func togglePlayPause() {
    guard hasTrack else { return }
    isPlaying.toggle()
    if isPlaying { hasYielded = false }
  }

  func next() {
    guard !queue.isEmpty else { return }
    isPlaying = queue.skipForward() && isPlaying
    elapsed = 0
  }

  func previous() {
    guard !queue.isEmpty else { return }
    if elapsed <= 3 { queue.skipBack() }
    elapsed = 0
  }

  func seek(toProgress fraction: Double) {
    elapsed = min(max(0, fraction), 1) * duration
  }

  func yieldAudio() {
    isPlaying = false
    hasYielded = true
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
