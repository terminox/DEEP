import SwiftUI

/// A single struck bell, rung to close a practice.
///
/// Deliberately much narrower than `SoundPlaying`: no queue, no transport, no
/// state worth observing — a chime is struck once and then rings out on its
/// own. Screens depend on this rather than the concrete `ChimePlayer`, so
/// previews and tests never reach real audio.
protocol ChimePlaying: AnyObject {
  /// Warm the sound so the strike lands without a first-play hitch. Safe to
  /// call more than once.
  func prepare()
  /// Strike the bell. Striking again restarts it from the top.
  func ring()
}

/// A bell that stays silent.
///
/// The environment default, so any tree that hasn't been handed a real one —
/// previews included — is hermetic by construction. Unlike the `#if DEBUG`
/// mocks elsewhere this one ships, because an unwired chime should be quiet
/// rather than missing.
final class SilentChime: ChimePlaying {
  func prepare() {}
  func ring() {}
}

extension EnvironmentValues {
  /// The bell that closes a practice. `DeepSessionRunModifier` injects the real
  /// instance from *outside* the presentation, so it outlives the session it
  /// ends and can ring on through the dismissal.
  @Entry var chimePlayer: any ChimePlaying = SilentChime()
}
