import AVFoundation
import Observation
import UIKit

/// The real playback engine: streams a track's `audioURL` over HTTP behind the
/// same `SoundPlaying` protocol the UI already uses — so no view changes when
/// swapping it in for the timer-based `SoundPlayer`.
///
/// An `AVQueuePlayer` always holds the current track *and* the one that
/// follows it, so when a track ends AVFoundation moves straight on by itself —
/// already buffered, and with no app code needing to run at that moment. That
/// is what keeps a playlist going with the phone locked: an app in the
/// background can be suspended the instant its audio stops, so starting the
/// next track from an end-of-track callback is too late.
///
/// Track duration comes from the backend model (reliable and instant); the
/// scrubber's `elapsed` is driven by a periodic time observer. Configured for
/// background audio (see `UIBackgroundModes` in Info.plist).
@MainActor
@Observable
final class StreamingSoundPlayer: SoundPlaying {
  private(set) var queue: SoundQueue

  var isPlaying: Bool = false
  var elapsed: TimeInterval = 0
  var volume: Double = 0.6 {
    didSet { player.volume = Float(volume) }
  }
  var repeatMode: RepeatMode {
    get { queue.repeatMode }
    set {
      guard newValue != queue.repeatMode else { return }
      queue.repeatMode = newValue
      defaults.set(newValue.rawValue, forKey: Self.repeatModeKey)
      enqueueUpcoming()
      publishNowPlaying()
    }
  }
  var isShuffled: Bool {
    get { queue.isShuffled }
    set {
      guard newValue != queue.isShuffled else { return }
      queue.setShuffled(newValue, using: &generator)
      enqueueUpcoming()
      publishNowPlaying()
    }
  }

  /// Where the listener's Repeat choice is kept between launches.
  static let repeatModeKey = "deep.sound.repeatMode"

  @ObservationIgnored private let player = AVQueuePlayer()
  /// The item playing now, and the pre-loaded one that follows it.
  @ObservationIgnored private var currentItem: AVPlayerItem?
  @ObservationIgnored private var upcomingItem: AVPlayerItem?
  /// Load-failure watches on the current and upcoming items.
  @ObservationIgnored private var statusObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]
  /// Tracks in a row that failed to load — once it covers the whole queue,
  /// nothing in it can play and the player stops rather than spinning.
  @ObservationIgnored private var consecutiveFailures = 0
  @ObservationIgnored private var resumesAfterInterruption = false
  @ObservationIgnored private var observers: [NSObjectProtocol] = []
  @ObservationIgnored private var timeObserver: Any?
  @ObservationIgnored private var sessionConfigured = false
  /// Claims the `.playback` session the first time anything plays.
  @ObservationIgnored private let activateSession: () -> Void
  @ObservationIgnored private var generator = SystemRandomNumberGenerator()
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let remoteControls: SoundRemoteControls

  /// Fired when a track plays through to its natural end — the reward seam.
  /// `AppDependencies` points this at the listen report; skips and manual
  /// nexts never fire it.
  @ObservationIgnored private let trackFinished: (@MainActor (SoundTrack) -> Void)?

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

  /// `activateSession` is swappable for tests: activating is a blocking
  /// round-trip to the media server, long enough to starve the real-clock
  /// suites a test run shares the main thread with.
  init(
    defaults: UserDefaults = .standard,
    activateSession: @escaping () -> Void = StreamingSoundPlayer.activatePlaybackSession,
    loadArtwork: @escaping (URL) async -> UIImage? = { _ in nil },
    trackFinished: (@MainActor (SoundTrack) -> Void)? = nil
  ) {
    self.defaults = defaults
    self.activateSession = activateSession
    self.trackFinished = trackFinished
    self.remoteControls = SoundRemoteControls(loadArtwork: loadArtwork)
    let savedMode = defaults.string(forKey: Self.repeatModeKey).flatMap(RepeatMode.init)
    self.queue = SoundQueue(repeatMode: savedMode ?? .off)
    player.volume = Float(volume)
    addTimeObserver()
    observePlayer()
  }

  // MARK: - Transport

  func play(_ entries: [SoundQueueEntry], at index: Int?, shuffled: Bool) {
    queue = queue.replacing(with: entries, startingAt: index, shuffled: shuffled, using: &generator)
    consecutiveFailures = 0
    loadCurrent(autoplay: true)
  }

  func togglePlayPause() {
    guard hasTrack else { return }
    if isPlaying {
      isPlaying = false
      player.pause()
    } else if currentItem == nil {
      loadCurrent(autoplay: true)
      return
    } else {
      startPlayback()
    }
    publishNowPlaying()
  }

  func next() {
    guard !queue.isEmpty else { return }
    let carriesOn = queue.skipForward()
    loadCurrent(autoplay: isPlaying && carriesOn)
  }

  func previous() {
    guard !queue.isEmpty else { return }
    if elapsed <= 3, queue.skipBack() {
      loadCurrent(autoplay: isPlaying)
    } else {
      seek(toProgress: 0)
    }
  }

  func seek(toProgress fraction: Double) {
    let target = min(max(0, fraction), 1) * duration
    elapsed = target
    player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    publishNowPlaying()
  }

  func yieldAudio() {
    if isPlaying {
      isPlaying = false
      player.pause()
    }
    remoteControls.detach()
  }

  // MARK: - Loading

  /// Replaces whatever the player holds with the queue's current track, plus
  /// the one that follows it.
  private func loadCurrent(autoplay: Bool) {
    elapsed = 0
    player.removeAllItems()
    forgetItems()
    currentItem = nil
    upcomingItem = nil

    guard let entry = queue.current, let url = entry.track.audioURL else {
      isPlaying = false
      publishNowPlaying()
      return
    }
    let item = makeItem(url: url, track: entry.track)
    player.insert(item, after: nil)
    currentItem = item
    enqueueUpcoming()

    if autoplay {
      startPlayback()
    } else {
      isPlaying = false
      player.pause()
    }
    publishNowPlaying()
  }

  /// Lines up what plays after the current track: dropped and rebuilt
  /// whenever the answer changes (Repeat, Shuffle) or the current track does.
  private func enqueueUpcoming() {
    if let upcomingItem {
      player.remove(upcomingItem)
      forget(upcomingItem)
      self.upcomingItem = nil
    }
    guard currentItem != nil,
          let entry = queue.upcoming,
          let url = entry.track.audioURL
    else { return }
    // A fresh item every time, even for Repeat One — a player item can only
    // ever sit in a queue once.
    let item = makeItem(url: url, track: entry.track)
    player.insert(item, after: nil)
    upcomingItem = item
  }

  private func startPlayback() {
    configureSessionIfNeeded()
    isPlaying = true
    player.play()
    remoteControls.attach(remoteActions)
  }

  // MARK: - Transitions

  /// A track played to its end. By now the player has already moved onto the
  /// pre-loaded item on its own; this only catches the queue up and lines up
  /// the track after that. End notifications arrive one per item and in
  /// order, so even several ends handled late (a busy main thread) each move
  /// the queue exactly one step.
  private func itemDidPlayToEnd(_ item: AVPlayerItem) {
    // The track rides on the item itself, so the report is right however far
    // the player has moved on since.
    guard let item = item as? TrackItem, item.owner == ObjectIdentifier(self) else { return }
    consecutiveFailures = 0
    trackFinished?(item.track)

    // An item from before a reload: nothing to catch up.
    guard item === currentItem else { return }
    forget(item)
    if let next = upcomingItem {
      queue.advanceAfterEnd()
      currentItem = next
      upcomingItem = nil
      elapsed = 0
      enqueueUpcoming()
      // Should the player have run dry before the line-up landed, it starts
      // on the newly queued item.
      if isPlaying { player.play() }
      publishNowPlaying()
    } else {
      // Nothing was lined up: either the queue is finished, or the next track
      // failed to pre-load and was dropped, in which case it gets a fresh try.
      let carriesOn = queue.advanceAfterEnd()
      loadCurrent(autoplay: carriesOn && isPlaying)
    }
  }

  private func itemFailed(_ item: AVPlayerItem) {
    if item === upcomingItem {
      // Drop it; when the current track ends the player runs dry and
      // `itemDidPlayToEnd` gives it a fresh load.
      player.remove(item)
      forget(item)
      upcomingItem = nil
      return
    }
    guard item === currentItem else { return }
    consecutiveFailures += 1
    let wasPlaying = isPlaying
    if consecutiveFailures < queue.entries.count, queue.skipUnplayable() {
      loadCurrent(autoplay: wasPlaying)
    } else {
      consecutiveFailures = 0
      loadCurrent(autoplay: false)
    }
  }

  // MARK: - Items

  /// A player item that knows which track it is, and which player made it.
  private final class TrackItem: AVPlayerItem {
    let track: SoundTrack
    let owner: ObjectIdentifier

    init(url: URL, track: SoundTrack, owner: ObjectIdentifier) {
      self.track = track
      self.owner = owner
      super.init(asset: AVURLAsset(url: url), automaticallyLoadedAssetKeys: nil)
    }
  }

  private func makeItem(url: URL, track: SoundTrack) -> AVPlayerItem {
    let item = TrackItem(url: url, track: track, owner: ObjectIdentifier(self))
    statusObservations[ObjectIdentifier(item)] = item.observe(\.status, options: [.new]) { @Sendable [weak self] item, _ in
      guard item.status == .failed else { return }
      Task { @MainActor [weak self] in self?.itemFailed(item) }
    }
    return item
  }

  private func forget(_ item: AVPlayerItem) {
    statusObservations.removeValue(forKey: ObjectIdentifier(item))?.invalidate()
  }

  private func forgetItems() {
    for observation in statusObservations.values { observation.invalidate() }
    statusObservations = [:]
  }

  // MARK: - Observation

  private func addTimeObserver() {
    let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      // Runs on the main queue, so we're on the MainActor.
      MainActor.assumeIsolated {
        guard let self, self.isPlaying, time.isNumeric else { return }
        self.elapsed = time.seconds
      }
    }
  }

  private func observePlayer() {
    let center = NotificationCenter.default
    observers.append(center.addObserver(
      forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main
    ) { [weak self] note in
      guard let item = note.object as? AVPlayerItem else { return }
      MainActor.assumeIsolated { self?.itemDidPlayToEnd(item) }
    })
    observers.append(center.addObserver(
      forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: nil, queue: .main
    ) { [weak self] note in
      guard let item = note.object as? AVPlayerItem else { return }
      MainActor.assumeIsolated { self?.itemFailed(item) }
    })

    let session = AVAudioSession.sharedInstance()
    observers.append(center.addObserver(
      forName: AVAudioSession.interruptionNotification, object: session, queue: .main
    ) { [weak self] note in
      let info = note.userInfo
      let type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt)
        .flatMap(AVAudioSession.InterruptionType.init)
      let options = (info?[AVAudioSessionInterruptionOptionKey] as? UInt)
        .map(AVAudioSession.InterruptionOptions.init) ?? []
      MainActor.assumeIsolated { self?.interrupted(type, options: options) }
    })
    observers.append(center.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: session, queue: .main
    ) { [weak self] note in
      let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
        .flatMap(AVAudioSession.RouteChangeReason.init)
      // Headphones out: the system has already paused the player.
      guard reason == .oldDeviceUnavailable else { return }
      MainActor.assumeIsolated {
        guard let self, self.isPlaying else { return }
        self.isPlaying = false
        self.publishNowPlaying()
      }
    })
  }

  /// A call or Siri took the audio. The system pauses the player; the UI
  /// follows, and playback comes back if the system says it should.
  private func interrupted(
    _ type: AVAudioSession.InterruptionType?,
    options: AVAudioSession.InterruptionOptions
  ) {
    switch type {
    case .began:
      resumesAfterInterruption = isPlaying
      if isPlaying {
        isPlaying = false
        publishNowPlaying()
      }
    case .ended:
      defer { resumesAfterInterruption = false }
      guard resumesAfterInterruption, options.contains(.shouldResume), hasTrack else { return }
      try? AVAudioSession.sharedInstance().setActive(true)
      startPlayback()
      publishNowPlaying()
    default:
      break
    }
  }

  // MARK: - Lock screen

  private var remoteActions: SoundRemoteControls.Actions {
    SoundRemoteControls.Actions(
      play: { [weak self] in
        guard let self, !self.isPlaying else { return }
        self.togglePlayPause()
      },
      pause: { [weak self] in self?.pause() },
      togglePlayPause: { [weak self] in self?.togglePlayPause() },
      next: { [weak self] in self?.next() },
      previous: { [weak self] in self?.previous() },
      seek: { [weak self] seconds in
        guard let self, self.duration > 0 else { return }
        self.seek(toProgress: seconds / self.duration)
      },
      setRepeatMode: { [weak self] mode in self?.repeatMode = mode },
      setShuffled: { [weak self] shuffled in self?.isShuffled = shuffled }
    )
  }

  private func publishNowPlaying() {
    remoteControls.publish(
      track: currentTrack,
      collection: collection,
      elapsed: elapsed,
      isPlaying: isPlaying,
      repeatMode: repeatMode,
      isShuffled: isShuffled
    )
  }

  private func configureSessionIfNeeded() {
    guard !sessionConfigured else { return }
    sessionConfigured = true
    activateSession()
  }

  nonisolated static func activatePlaybackSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
  }
}
