import Foundation

/// Every DEEP Premium lock decision in the app, in one place.
///
/// Screens never write their own "is this locked" expression: they ask here,
/// passing the one answer `PremiumAccess.hasPremium` gives them. Pure — no
/// SwiftUI, no stores — so each rule is a unit test away.
///
/// Two inputs:
///
/// 1. **The server's verdict** (`isLocked` on a track or collection), present
///    whenever the content was fetched from a server that knows who asked.
///    For sounds it can only *add* a lock: a `false` verdict was true for the
///    member who fetched it, and a copy cached before a lapse (a saved
///    playlist offline, a detail screen whose re-fetch failed) would otherwise
///    keep playing premium audio after the membership ended.
/// 2. **The client rule** (`isPremium`), which always applies to a listener
///    without DEEP Premium.
///
/// Plants are the exception: there the server's verdict wins both ways,
/// because it is how a grandfathered plant stays open, and a plant carries
/// no audio to leak.
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
    return collection.isLocked == true || collection.isPremium
  }

  /// Whether one track is locked *within the collection it is played from* —
  /// so a free track inside a premium collection is locked by its collection.
  static func isLocked(
    _ track: SoundTrack,
    in collection: SoundCollection,
    hasPremium: Bool
  ) -> Bool {
    guard !hasPremium else { return false }
    return track.isLocked == true || track.isPremium || isLocked(collection, hasPremium: hasPremium)
  }

  /// Whether the server withheld this premium track's audio. A track like
  /// that must never start: the player would load it and play silence. It
  /// happens to a member whose purchase the server hasn't heard about yet —
  /// unlocked on the store's word, still withheld by the server — and to
  /// content cached across a lapse. A free track without audio is fixture
  /// content, not a withholding, and is left to the player.
  static func isWithheld(_ track: SoundTrack, in collection: SoundCollection) -> Bool {
    guard track.audioURL == nil else { return false }
    return track.isLocked == true || track.isPremium
      || collection.isLocked == true || collection.isPremium
  }

  /// Whether tapping this track may start it. Anything else opens the paywall.
  static func canStart(_ track: SoundTrack, in collection: SoundCollection, hasPremium: Bool) -> Bool {
    !isLocked(track, in: collection, hasPremium: hasPremium) && !isWithheld(track, in: collection)
  }

  /// The entries a queue may hold, in order: Play, Shuffle and a tapped row
  /// all queue these, so a run never carries on into a locked sound — or into
  /// one the server withheld.
  static func playable(_ entries: [SoundQueueEntry], hasPremium: Bool) -> [SoundQueueEntry] {
    entries.filter { canStart($0.track, in: $0.collection, hasPremium: hasPremium) }
  }

  // MARK: - Plants

  /// Whether a plant is locked for this member. The plant they are already
  /// growing never is — not even after a lapse: taking someone's garden away
  /// is a punishment, and only switching *to* a premium plant needs the
  /// membership.
  static func isLocked(_ plant: Plant, growing growingID: String?, hasPremium: Bool) -> Bool {
    guard plant.id != growingID, !hasPremium else { return false }
    return plant.isLocked ?? plant.isPremium
  }

  // MARK: - Queues

  /// A collection's tracks as playable queue entries.
  static func playable(_ collection: SoundCollection, hasPremium: Bool) -> [SoundQueueEntry] {
    playable(
      collection.tracks.map { SoundQueueEntry(track: $0, collection: collection) },
      hasPremium: hasPremium
    )
  }
}
