import SwiftUI
import Observation

/// The playback surface the Deep Sound UI depends on.
///
/// Screens depend on this protocol rather than the concrete `SoundPlayer`, so
/// they can be previewed and tested against `MockSoundPlayer` with no timers or
/// audio side effects. It refines `Observable` so SwiftUI tracks changes through
/// the `any SoundPlaying` existential exactly as it would a concrete player.
protocol SoundPlaying: AnyObject, Observable {
  var collection: SoundCollection? { get }
  var currentTrack: SoundTrack? { get }
  var hasTrack: Bool { get }
  var isPlaying: Bool { get }
  /// Seconds into the current track.
  var elapsed: TimeInterval { get }
  var duration: TimeInterval { get }
  /// 0...1 playback position.
  var progress: Double { get }
  /// 0...1 — purely visual for now.
  var volume: Double { get set }

  func play(_ collection: SoundCollection, at index: Int)
  func togglePlayPause()
  func next()
  func previous()
  /// Seek to a 0...1 fraction of the current track.
  func seek(toProgress fraction: Double)
}

extension SoundPlaying {
  /// Start a collection from its first track.
  func play(_ collection: SoundCollection) {
    play(collection, at: 0)
  }

  /// Pause playback if something is playing; otherwise a no-op. Guided flows
  /// (Deep Session) call this on entry — the track stays loaded so the mini
  /// player picks up right where the listener left off.
  func pause() {
    if isPlaying { togglePlayPause() }
  }
}

extension EnvironmentValues {
  /// The player the Deep Sound flow is driven by. The coordinator injects the
  /// real (or, in previews, mocked) instance; the default is only a fallback.
  @Entry var soundPlayer: any SoundPlaying = SoundPlayer()
}
