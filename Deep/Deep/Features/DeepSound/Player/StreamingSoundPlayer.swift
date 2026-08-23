import AVFoundation
import Observation

/// The real playback engine: streams a track's `audioURL` over HTTP with
/// `AVPlayer`, behind the same `SoundPlaying` protocol the UI already uses — so
/// no view changes when swapping it in for the timer-based `SoundPlayer`.
///
/// Track duration comes from the backend model (reliable and instant); the
/// scrubber's `elapsed` is driven by an `AVPlayer` periodic time observer.
/// Configured for background audio (see `UIBackgroundModes` in Info.plist).
@MainActor
@Observable
final class StreamingSoundPlayer: SoundPlaying {
  private(set) var collection: SoundCollection?
  private(set) var queue: [SoundTrack] = []
  private(set) var index: Int = 0

  var isPlaying: Bool = false
  var elapsed: TimeInterval = 0
  var volume: Double = 0.6 {
    didSet { player.volume = Float(volume) }
  }

  @ObservationIgnored private let player = AVPlayer()
  @ObservationIgnored private var timeObserver: Any?
  @ObservationIgnored private var endObserver: NSObjectProtocol?
  @ObservationIgnored private var sessionConfigured = false

  /// Fired when a track plays through to its natural end — the reward seam.
  /// `AppDependencies` points this at the listen report; skips and manual
  /// nexts never fire it.
  @ObservationIgnored private let trackFinished: (@MainActor (SoundTrack) -> Void)?

  var currentTrack: SoundTrack? {
    queue.indices.contains(index) ? queue[index] : nil
  }
  var hasTrack: Bool { currentTrack != nil }
  var duration: TimeInterval { currentTrack?.duration ?? 0 }
  var progress: Double {
    guard duration > 0 else { return 0 }
    return min(1, max(0, elapsed / duration))
  }

  init(trackFinished: (@MainActor (SoundTrack) -> Void)? = nil) {
    self.trackFinished = trackFinished
    player.volume = Float(volume)
    addTimeObserver()
  }

  // MARK: - Transport

  func play(_ collection: SoundCollection, at index: Int = 0) {
    self.collection = collection
    self.queue = collection.tracks
    self.index = min(max(0, index), max(0, collection.tracks.count - 1))
    loadCurrent(autoplay: true)
  }

  func togglePlayPause() {
    guard hasTrack else { return }
    isPlaying.toggle()
    if isPlaying {
      configureSessionIfNeeded()
      player.play()
    } else {
      player.pause()
    }
  }

  func next() {
    guard !queue.isEmpty else { return }
    index = (index + 1) % queue.count
    loadCurrent(autoplay: isPlaying)
  }

  func previous() {
    guard !queue.isEmpty else { return }
    if elapsed > 3 {
      seek(toProgress: 0)
    } else {
      index = (index - 1 + queue.count) % queue.count
      loadCurrent(autoplay: isPlaying)
    }
  }

  func seek(toProgress fraction: Double) {
    let target = min(max(0, fraction), 1) * duration
    elapsed = target
    player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
  }

  // MARK: - Loading

  private func loadCurrent(autoplay: Bool) {
    elapsed = 0
    guard let track = currentTrack, let url = track.audioURL else {
      player.replaceCurrentItem(with: nil)
      isPlaying = false
      return
    }
    let item = AVPlayerItem(url: url)
    player.replaceCurrentItem(with: item)
    observeEnd(of: item)
    if autoplay {
      configureSessionIfNeeded()
      isPlaying = true
      player.play()
    } else {
      isPlaying = false
    }
  }

  // MARK: - Observation

  private func addTimeObserver() {
    let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      // Runs on the main queue, so we're on the MainActor.
      MainActor.assumeIsolated {
        guard let self, self.isPlaying else { return }
        self.elapsed = time.seconds
      }
    }
  }

  private func observeEnd(of item: AVPlayerItem) {
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
    }
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        // Capture the finished track BEFORE advancing — `next()` moves
        // `currentTrack` onto the following one.
        let finished = self.currentTrack
        self.next()
        if let finished {
          self.trackFinished?(finished)
        }
      }
    }
  }

  private func configureSessionIfNeeded() {
    guard !sessionConfigured else { return }
    sessionConfigured = true
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
  }
}
