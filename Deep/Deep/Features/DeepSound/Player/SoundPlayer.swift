import Foundation
import Observation

/// The single source of truth for playback state across the feature.
///
/// There is no real audio yet. A timer simulates progress so the scrubber,
/// mini-player, and Now Playing artwork all behave like the real thing — the
/// UI is fully wired and only the audio engine is missing.
@Observable
final class SoundPlayer {
  private(set) var collection: SoundCollection?
  private(set) var queue: [SoundTrack] = []
  private(set) var index: Int = 0

  var isPlaying: Bool = false
  /// Seconds into the current track.
  var elapsed: TimeInterval = 0
  /// 0...1 — purely visual for now.
  var volume: Double = 0.6

  @ObservationIgnored private var ticker: Timer?

  var currentTrack: SoundTrack? {
    queue.indices.contains(index) ? queue[index] : nil
  }
  var hasTrack: Bool { currentTrack != nil }
  var duration: TimeInterval { currentTrack?.duration ?? 0 }
  var progress: Double {
    guard duration > 0 else { return 0 }
    return min(1, max(0, elapsed / duration))
  }

  // MARK: - Transport

  /// Start a collection from a given track.
  func play(_ collection: SoundCollection, at index: Int = 0) {
    self.collection = collection
    self.queue = collection.tracks
    self.index = min(max(0, index), max(0, collection.tracks.count - 1))
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
