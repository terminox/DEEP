import SwiftUI
import Observation

/// The playback surface the DEEP Sound UI depends on.
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
  /// What happens when a track ends — see `SoundQueue` for the rules.
  var repeatMode: RepeatMode { get set }
  /// Turning shuffle on keeps the current track and deals the rest in a random
  /// order; turning it off resumes the original order from the current track.
  var isShuffled: Bool { get set }

  /// Loads a queue and starts it. Each entry names the collection its track
  /// came from, so a queue may cross collections (a playlist) or stay inside
  /// one (a collection) without the player needing to know which it has.
  /// Shuffled with a `nil` index, it starts from a random track.
  func play(_ entries: [SoundQueueEntry], at index: Int?, shuffled: Bool)
  func togglePlayPause()
  func next()
  func previous()
  /// Seek to a 0...1 fraction of the current track.
  func seek(toProgress fraction: Double)
  /// Another feature is taking over the audio (a DEEP Session, Global Pause):
  /// pause, and let go of the lock screen's controls so they reach the new
  /// owner. The track stays loaded; playing again takes them back.
  func yieldAudio()
}

extension SoundPlaying {
  /// Start a queue from a given track, keeping the listener's shuffle setting.
  func play(_ entries: [SoundQueueEntry], at index: Int) {
    play(entries, at: index, shuffled: isShuffled)
  }

  /// Start a collection, optionally from a given track — every entry shares
  /// the one collection, so `collection` stays put for the whole queue.
  func play(_ collection: SoundCollection, at index: Int = 0) {
    play(
      collection.tracks.map { SoundQueueEntry(track: $0, collection: collection) },
      at: index
    )
  }

  /// Pause playback if something is playing; otherwise a no-op.
  func pause() {
    if isPlaying { togglePlayPause() }
  }
}

extension EnvironmentValues {
  /// The player the DEEP Sound flow is driven by. The coordinator injects the
  /// real (or, in previews, mocked) instance; the default is only a fallback.
  @Entry var soundPlayer: any SoundPlaying = SoundPlayer()
}
