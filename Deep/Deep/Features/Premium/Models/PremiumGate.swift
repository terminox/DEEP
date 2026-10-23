import Foundation

/// Every DEEP Premium lock decision in the app, in one place.
///
/// Screens never write their own "is this locked" expression: they ask here,
/// passing the one answer `PremiumAccess.hasPremium` gives them. Pure — no
/// SwiftUI, no stores — so each rule is a unit test away.
///
/// Two inputs, in order of authority:
///
/// 1. **The server's verdict** (`isLocked` on a track or collection), present
///    whenever the content was fetched from a server that knows who asked. It
///    already accounts for the listener's entitlement, so it wins.
/// 2. **The client rule** (`isPremium`), the fallback for content that came
///    without a verdict — an older server, or a playlist cached before the
///    field existed.
///
/// Either way, `hasPremium == true` always unlocks *visually*: a member whose
/// purchase the server hasn't heard about yet is never shown a lock. The worst
/// that costs is a tap on a track whose audio the server still withholds.
enum PremiumGate {
  // MARK: - Sounds

  /// Whether a collection as a whole reads as locked — the badge on its
  /// artwork. A free collection holding a premium track is not locked; that
  /// track is.
  static func isLocked(_ collection: SoundCollection, hasPremium: Bool) -> Bool {
    guard !hasPremium else { return false }
    return collection.isLocked ?? collection.isPremium
  }

  /// Whether one track is locked *within the collection it is played from* —
  /// so a free track inside a premium collection is locked by its collection.
  static func isLocked(
    _ track: SoundTrack,
    in collection: SoundCollection,
    hasPremium: Bool
  ) -> Bool {
    guard !hasPremium else { return false }
    if let verdict = track.isLocked { return verdict }
    return isLocked(collection, hasPremium: hasPremium) || track.isPremium
  }

  /// The entries a queue may hold, in order: Play, Shuffle and a tapped row
  /// all queue these, so a run never carries on into a locked sound.
  static func playable(_ entries: [SoundQueueEntry], hasPremium: Bool) -> [SoundQueueEntry] {
    entries.filter { !isLocked($0.track, in: $0.collection, hasPremium: hasPremium) }
  }

  /// A collection's tracks as playable queue entries.
  static func playable(_ collection: SoundCollection, hasPremium: Bool) -> [SoundQueueEntry] {
    playable(
      collection.tracks.map { SoundQueueEntry(track: $0, collection: collection) },
      hasPremium: hasPremium
    )
  }
}
