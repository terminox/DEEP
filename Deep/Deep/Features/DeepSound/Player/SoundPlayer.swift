import Foundation
import Observation

/// A stand-in engine with no audio: a timer simulates progress so the
/// scrubber, mini-player, and Now Playing artwork behave like the real thing.
/// The queue rules are the real ones — `SoundQueue` — so it advances, repeats
/// and shuffles exactly as `StreamingSoundPlayer` does.
@Observable
final class SoundPlayer: SoundPlaying {
  /// No audio here, so every track counts as playable.
  private(set) var queue = SoundQueue(canPlay: { _ in true })

  var isPlaying: Bool = false
  /// Seconds into the current track.
  var elapsed: TimeInterval = 0
  /// 0...1 — purely visual for now.
  var volume: Double = 0.6
  var repeatMode: RepeatMode {
    get { queue.repeatMode }
    set { queue.repeatMode = newValue }
  }
  var isShuffled: Bool {
    get { queue.isShuffled }
    set { queue.setShuffled(newValue, using: &generator) }
  }

  @ObservationIgnored private var ticker: Timer?
  @ObservationIgnored private var generator = SystemRandomNumberGenerator()

  /// The collection the *current* track came from — constant while a
  /// collection plays, changing track by track through a playlist.
  var collection: SoundCollection? { queue.current?.collection }
  var currentTrack: SoundTrack? { queue.current?.track }
  var hasTrack: Bool { currentTrack != nil }
  var duration: TimeInterval { currentTrack?.duration ?? 0 }
  var progress: Double {
    guard duration > 0 else { return 0 }
    return min(1, max(0, elapsed / duration))
  }

  // MARK: - Transport

  func play(_ entries: [SoundQueueEntry], at index: Int?, shuffled: Bool) {
    queue = queue.replacing(with: entries, startingAt: index, shuffled: shuffled, using: &generator)
    elapsed = 0
    isPlaying = hasTrack
    restartTicker()
  }

  func togglePlayPause() {
    guard hasTrack else { return }
    isPlaying.toggle()
    isPlaying ? restartTicker() : stopTicker()
  }

  func next() {
    guard !queue.isEmpty else { return }
    let carriesOn = queue.skipForward()
    elapsed = 0
    isPlaying = isPlaying && carriesOn
    restartTicker()
  }

  /// Apple Music behaviour: restart the track unless we're within the first
  /// few seconds, in which case step to the previous track.
  func previous() {
    guard !queue.isEmpty else { return }
    if elapsed <= 3 { queue.skipBack() }
    elapsed = 0
    restartTicker()
  }

  /// Seek to a 0...1 fraction of the current track.
  func seek(toProgress fraction: Double) {
    elapsed = min(max(0, fraction), 1) * duration
  }

  func yieldAudio() {
    pause()
  }

  // MARK: - Ticker

  private func restartTicker() {
    stopTicker()
    guard isPlaying else { return }
    ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      self?.tick()
    }
  }

  private func stopTicker() {
    ticker?.invalidate()
    ticker = nil
  }

  private func tick() {
    guard isPlaying else { return }
    elapsed += 0.5
    guard elapsed >= duration else { return }
    elapsed = 0
    if !queue.advanceAfterEnd() {
      isPlaying = false
      stopTicker()
    }
  }
}
