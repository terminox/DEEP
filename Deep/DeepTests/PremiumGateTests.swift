import Testing
import Foundation
@testable import Deep

/// Every DEEP Premium lock rule: the server's verdict first, the client rule as
/// the fallback for content cached without one, and membership unlocking all
/// of it.
@MainActor
struct PremiumGateTests {
  private static func track(
    _ id: String,
    premium: Bool = false,
    locked: Bool? = nil
  ) -> SoundTrack {
    SoundTrack(id: id, title: id, duration: 60, isPremium: premium, isLocked: locked)
  }

  private static func collection(
    premium: Bool = false,
    locked: Bool? = nil,
    tracks: [SoundTrack]
  ) -> SoundCollection {
    SoundCollection(
      id: "c",
      title: "C",
      subtitle: "",
      palette: .mist,
      imageURL: nil,
      isPremium: premium,
      isLocked: locked,
      tracks: tracks
    )
  }

  // MARK: - Tracks

  @Test("A free track in a free collection is open")
  func freeTrackOpen() {
    let free = Self.track("a")
    #expect(!PremiumGate.isLocked(free, in: Self.collection(tracks: [free]), hasPremium: false))
  }

  @Test("A premium track is locked for the free plan, open for a member")
  func premiumTrack() {
    let premium = Self.track("a", premium: true)
    let home = Self.collection(tracks: [premium])
    #expect(PremiumGate.isLocked(premium, in: home, hasPremium: false))
    #expect(!PremiumGate.isLocked(premium, in: home, hasPremium: true))
  }

  @Test("A free track is locked by the premium collection it sits in")
  func lockedByCollection() {
    let free = Self.track("a")
    let premiumHome = Self.collection(premium: true, tracks: [free])
    #expect(PremiumGate.isLocked(free, in: premiumHome, hasPremium: false))
    #expect(!PremiumGate.isLocked(free, in: premiumHome, hasPremium: true))
  }

  @Test("The server's track verdict beats the client rule, both ways")
  func serverTrackVerdictWins() {
    // Premium, but the server knows this caller is entitled.
    let opened = Self.track("a", premium: true, locked: false)
    #expect(!PremiumGate.isLocked(opened, in: Self.collection(premium: true, tracks: [opened]), hasPremium: false))
    // Marked free, but the server withheld it anyway.
    let withheld = Self.track("b", locked: true)
    #expect(PremiumGate.isLocked(withheld, in: Self.collection(tracks: [withheld]), hasPremium: false))
  }

  @Test("Membership unlocks visually even when the server still says locked")
  func membershipBeatsStaleVerdict() {
    let stale = Self.track("a", premium: true, locked: true)
    #expect(!PremiumGate.isLocked(stale, in: Self.collection(tracks: [stale]), hasPremium: true))
  }

  @Test("A collection's server verdict reaches a track that has none")
  func collectionVerdictReachesTrack() {
    let free = Self.track("a")
    let lockedHome = Self.collection(locked: true, tracks: [free])
    #expect(PremiumGate.isLocked(free, in: lockedHome, hasPremium: false))
  }

  // MARK: - Collections

  @Test("A collection reads locked from its verdict, else from its flag")
  func collectionLock() {
    #expect(!PremiumGate.isLocked(Self.collection(tracks: []), hasPremium: false))
    #expect(PremiumGate.isLocked(Self.collection(premium: true, tracks: []), hasPremium: false))
    #expect(!PremiumGate.isLocked(Self.collection(premium: true, locked: false, tracks: []), hasPremium: false))
    #expect(!PremiumGate.isLocked(Self.collection(premium: true, tracks: []), hasPremium: true))
  }

  @Test("A free collection holding a premium track is not itself locked")
  func mixedCollectionNotLocked() {
    let home = Self.collection(tracks: [Self.track("a"), Self.track("b", premium: true)])
    #expect(!PremiumGate.isLocked(home, hasPremium: false))
  }

  // MARK: - Queues

  @Test("The playable queue drops locked tracks and keeps order")
  func playableFilter() {
    let home = Self.collection(tracks: [
      Self.track("a"),
      Self.track("b", premium: true),
      Self.track("c"),
    ])
    #expect(PremiumGate.playable(home, hasPremium: false).map(\.track.id) == ["a", "c"])
    #expect(PremiumGate.playable(home, hasPremium: true).map(\.track.id) == ["a", "b", "c"])
  }

  @Test("A premium collection's queue is empty for the free plan")
  func premiumCollectionQueueEmpty() {
    let home = Self.collection(premium: true, tracks: [Self.track("a"), Self.track("b")])
    #expect(PremiumGate.playable(home, hasPremium: false).isEmpty)
  }

  @Test("Mixed-origin playlist entries are each judged by their own collection")
  func playlistEntries() {
    let free = Self.track("a")
    let entries = [
      SoundQueueEntry(track: free, collection: Self.collection(tracks: [])),
      SoundQueueEntry(track: Self.track("b"), collection: Self.collection(premium: true, tracks: [])),
    ]
    #expect(PremiumGate.playable(entries, hasPremium: false).map(\.track.id) == ["a"])
  }

  // MARK: - Cache compatibility

  @Test("A track cached before isLocked existed still decodes, as unknown")
  func legacyTrackDecodes() throws {
    let legacy = Data("""
    {"id":"t","title":"T","duration":60,"kind":{"instrumental":{}},"isPremium":true}
    """.utf8)
    let track = try JSONDecoder().decode(SoundTrack.self, from: legacy)
    #expect(track.isLocked == nil)
    #expect(track.isPremium)
  }
}
