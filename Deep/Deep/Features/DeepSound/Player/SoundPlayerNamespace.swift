import Foundation

/// Stable identifier shared between the mini-player (the zoom *source*) and Now
/// Playing (the zoom *destination*) so the whole bar morphs into the full player
/// via `matchedTransitionSource` / `navigationTransition(.zoom)`.
enum SoundPlayerNamespace {
  static let player = "deepSound.player"
}
