import Foundation
import Observation

/// The single source of truth for playback state across the feature.
///
/// There is no real audio yet. A timer simulates progress so the scrubber,
/// mini-player, and Now Playing artwork all behave like the real thing — the
/// UI is fully wired and only the audio engine is missing.
@Observable
final class SoundPlayer: SoundPlaying {
  private(set) var queue: [SoundQueueEntry] = []
  private(set) var index: Int = 0

  var isPlaying: Bool = false
  /// Seconds into the current track.
  var elapsed: TimeInterval = 0
  /// 0...1 — purely visual for now.
  var volume: Double = 0.6

  @ObservationIgnored private var ticker: Timer?

  /// The collection the *current* track came from — constant while a
  /// collection plays, changing track by track through a playlist.
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

  // MARK: - Transport

  func play(_ entries: [SoundQueueEntry], at index: Int) {
    self.queue = entries
    self.index = min(max(0, index), max(0, entries.count - 1))
    elapsed = 0
    isPlaying = true
    restartTicker()
  }

  func togglePlayPause() {
    guard hasTrack else { return }
    isPlaying.toggle()
    isPlaying ? restartTicker() : stopTicker()
  }

  func next() {
    guard !queue.isEmpty else { return }
    index = (index + 1) % queue.count
    elapsed = 0
    if isPlaying { restartTicker() }
  }

  /// Apple Music behaviour: restart the track unless we're within the first
  /// few seconds, in which case step to the previous track.
  func previous() {
    guard !queue.isEmpty else { return }
    if elapsed > 3 {
      elapsed = 0
    } else {
      index = (index - 1 + queue.count) % queue.count
      elapsed = 0
    }
    if isPlaying { restartTicker() }
  }

  /// Seek to a 0...1 fraction of the current track.
  func seek(toProgress fraction: Double) {
    elapsed = min(max(0, fraction), 1) * duration
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
    if elapsed >= duration {
      next()
    }
  }
}
